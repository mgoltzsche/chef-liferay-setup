require 'uri'

# --- Create Liferay system user ---
user node['liferay']['user'] do
  comment 'Liferay User'
  home "/home/#{node['liferay']['user']}"
  shell '/bin/bash'
  supports :manage_home=>true
end

# --- Download and install Liferay ---
downloadDir = "/home/#{node['liferay']['user']}/liferay_downloads"
liferayZipFile = File.basename(URI.parse(node['liferay']['download_url']).path)
liferayExtractionDir = liferayZipFile.gsub(/liferay-portal-[\w]+-(([\d]+\.?)+-[\w]+(-[\w]+)?)-[\d]+.zip/, 'liferay-portal-\1')
liferayHome = "#{node['liferay']['install_directory']}/#{liferayExtractionDir}";
liferayHomeLink = "#{node['liferay']['install_directory']}/liferay";

directory downloadDir do
  owner node['liferay']['user']
  group node['liferay']['group']
  mode 00755
  action :create
end

remote_file "#{downloadDir}/#{liferayZipFile}" do
  owner node['liferay']['user']
  group node['liferay']['group']
  source node['liferay']['download_url']
  action :create_if_missing
end

execute "Extract Liferay" do
  cwd downloadDir
  user 'root'
  group 'root'
  command "unzip -qd #{node['liferay']['install_directory']} #{liferayZipFile}"
  not_if {File.exist?(liferayHome)}
  notifies :run, "execute[Create symlinks]", :immediately
end

execute "Create symlinks" do
  user 'root'
  group 'root'
  command <<-EOH
rm -rf #{node['liferay']['install_directory']}/liferay &&
ln -s #{liferayHome} #{liferayHomeLink} &&
ln -s #{liferayHome}/$(ls #{liferayHome} | grep tomcat) #{liferayHome}/tomcat
  EOH
  action :nothing
  notifies :run, "execute[Delete *.bat files]", :immediately
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

directory "#{liferayHomeLink}/tomcat/webapps/resources-importer-web" do
  recursive true
  action :delete
end

# --- Configure Liferay installation ---
template "#{liferayHome}/tomcat/bin/setenv.sh" do
  owner node['liferay']['user']
  group node['liferay']['group']
  source "setenv.sh.erb"
  mode 01700
  variables({
    :java_opts => node['liferay']['java_opts']
  })
end

directory "#{liferayHome}/deploy" do
  owner node['liferay']['user']
  group node['liferay']['group']
  mode 01750
  action :create
  recursive true
end

template "#{liferayHome}/tomcat/conf/server.xml" do
  owner node['liferay']['user']
  group node['liferay']['group']
  source "server.xml.erb"
  mode 00700
  variables({
    :port => node['liferay']['port']
  })
end

template "#{liferayHome}/tomcat/conf/server.xml" do
  owner node['liferay']['user']
  group node['liferay']['group']
  source "server.xml.erb"
  mode 00700
  variables({
    :port => node['liferay']['port']
  })
end

template "#{liferayHome}/portal-ext.properties" do
  owner node['liferay']['user']
  group node['liferay']['group']
  source "portal-ext.properties.erb"
  mode 00700
  variables({
    :liferay_home => liferayHome,
    :postgres_port => node['liferay']['postgresql']['port'],
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
    :user => node['liferay']['user'],
    :group => node['liferay']['group']
  })
end

template "/etc/logrotate.d/liferay" do
  source "logrotate.d.liferay.erb"
  mode 00755
  variables({
    :liferay_log_home => "#{liferayHomeLink}/tomcat/logs"
  })
end

# --- (Re)start Liferay ---
service "liferay" do
  action :restart
end
