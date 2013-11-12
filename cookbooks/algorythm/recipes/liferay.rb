require 'uri'

usr = node['liferay']['user']
downloadDir = "/home/#{usr}/Downloads"
liferayZipFile = File.basename(URI.parse(node['liferay']['download_url']).path)
liferayExtractionDir = liferayZipFile.gsub(/liferay-portal-[\w]+-(([\d]+\.?)+-[\w]+(-[\w]+)?)-[\d]+.zip/, 'liferay-portal-\1')
liferayHome = "#{node['liferay']['install_directory']}/#{liferayExtractionDir}";
liferayHomeLink = "#{node['liferay']['install_directory']}/liferay";
dbname = node['liferay']['postgresql']['database']

# --- Create Liferay system user ---
user usr do
  comment 'Liferay User'
  home "/home/#{usr}"
  shell '/bin/bash'
  supports :manage_home=>true
end

# --- Download and install Liferay ---
directory downloadDir do
  owner usr
  group usr
  mode 00755
  action :create
end

remote_file "#{downloadDir}/#{liferayZipFile}" do
  owner usr
  group usr
  source node['liferay']['download_url']
  action :create_if_missing
end

execute "Extract Liferay" do
  cwd downloadDir
  user 'root'
  group 'root'
  command "unzip -qd #{node['liferay']['install_directory']} #{liferayZipFile}"
  not_if {File.exist?(liferayHome)}
  notifies :run, "execute[Create symlinks and change owner]", :immediately
end

execute "Create symlinks and change owner" do
  user 'root'
  group 'root'
  command <<-EOH
rm -rf #{node['liferay']['install_directory']}/liferay &&
ln -s #{liferayHome} #{liferayHomeLink} &&
ln -s #{liferayHome}/$(ls #{liferayHome} | grep tomcat) #{liferayHome}/tomcat &&
chown -R #{usr}:#{usr} #{liferayHome}
  EOH
  action :nothing
  notifies :run, "execute[Rename ROOT WAR]", :immediately
end

execute "Rename ROOT WAR" do
  user usr
  group usr
  cwd "#{liferayHome}/tomcat/webapps"
  command "mv ROOT portal"
  action :nothing
  notifies :run, "execute[Delete *.bat files]", :immediately
end

directory "#{liferayHome}/tomcat/webapps/liferay/META-INF" do
  owner usr
  group usr
  mode 00755
  action :create
end

template "#{liferayHome}/tomcat/webapps/liferay/META-INF/context.xml" do
  user usr
  group usr
  source "liferay.context.xml.erb"
  mode 00644
end

# --- Clean up Liferay installation ---
execute "Delete *.bat files" do
  cwd "#{liferayHomeLink}/tomcat/bin/"
  user 'root'
  group 'root'
  command "ls | grep '\\.bat$' | xargs rm"
  action :nothing
end

directory "#{liferayHomeLink}/tomcat/webapps/welcome-theme" do
  recursive true
  action :delete
end

# --- Create Liferay postgres user and database
execute "Create liferay postgres user '#{node['liferay']['postgresql']['user']}'" do
  user 'postgres'
  command "psql -U postgres -c \"CREATE USER #{node['liferay']['postgresql']['user']};\""
  not_if("psql -U postgres -c \"SELECT * FROM pg_user WHERE usename='#{node['liferay']['postgresql']['user']}';\" | grep #{node['liferay']['postgresql']['user']}", :user => 'postgres')
end

execute "Set postgres user password of '#{node['liferay']['postgresql']['user']}'" do
  user 'postgres'
  command "psql -U postgres -c \"ALTER ROLE #{node['liferay']['postgresql']['user']} ENCRYPTED PASSWORD '#{node['liferay']['postgresql']['password']}';\""
end

execute "Create database '#{dbname}'" do
  user 'postgres'
  command "createdb '#{dbname}' -O #{node['liferay']['postgresql']['user']} -E UTF8 -T template0"
  not_if("psql -c \"SELECT datname FROM pg_catalog.pg_database WHERE datname='#{dbname}';\" | grep '#{dbname}'", :user => 'postgres')
end

# --- Configure Liferay tomcat ---
directory "#{liferayHome}/deploy" do
  owner usr
  group usr
  mode 01750
  action :create
  recursive true
end

template "#{liferayHome}/tomcat/bin/setenv.sh" do
  owner usr
  group usr
  source "liferay.tomcat.setenv.sh.erb"
  mode 01700
  variables({
    :java_opts => node['liferay']['java_opts']
  })
end

template "#{liferayHome}/tomcat/conf/server.xml" do
  owner usr
  group usr
  source "liferay.tomcat.server.xml.erb"
  mode 00700
  variables({
    :port => node['liferay']['port']
  })
end

# --- Configure Liferay ---
template "#{liferayHome}/portal-ext.properties" do
  owner usr
  group usr
  source "portal-ext.properties.erb"
  mode 00700
  variables({
    :liferay_home => liferayHome,
    :postgres_port => node['liferay']['postgresql']['port'],
    :postgres_database => node['liferay']['postgresql']['database'],
    :postgres_user => node['liferay']['postgresql']['user'],
    :postgres_password => node['liferay']['postgresql']['password'],
    :company_name => node['liferay']['company_default_name'],
    :hostname => node['liferay']['hostname'],
    :admin_name => node['liferay']['admin']['name'],
    :admin_email => node['liferay']['admin']['email']
  })
end

# --- Register Liferay as service ---
template "/etc/init.d/liferay" do
  source "init.d.liferay.erb"
  mode 00755
  variables({
    :liferay_home => liferayHomeLink,
    :user => usr,
    :group => usr
  })
end

template "/etc/logrotate.d/liferay" do
  source "logrotate.d.liferay.erb"
  mode 00755
  variables({
    :liferay_log_home => "#{liferayHomeLink}/tomcat/logs"
  })
end

# --- Configure default nginx vhost ---
directory '/usr/share/nginx/cache/liferay' do
  owner 'www-data'
  group 'www-data'
  mode 00744
  recursive true
  action :create
end

cookbook_file '/usr/share/nginx/www/index.html'
cookbook_file '/usr/share/nginx/www/50x.html'

template "/etc/nginx/sites-available/default" do
  source "liferay.nginx.vhost.erb"
  mode 00700
  variables({
    :hostname => node['liferay']['hostname'],
    :port => node['liferay']['port']
  })
end

# --- Restart nginx ---
service 'nginx' do
  action :restart
end

# --- (Re)start Liferay ---
service "liferay" do
  action :restart
end
