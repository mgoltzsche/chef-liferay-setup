usr = node['redmine']['user']
downloadDir = "/home/#{usr}/Downloads"
redmineZipFile = File.basename(URI.parse(node['redmine']['download_url']).path)
redmineExtractionDir = redmineZipFile.gsub(/(.*)\.zip/, '\1')
redmineHome = "#{node['redmine']['install_directory']}/#{redmineExtractionDir}";
redmineHomeLink = "#{node['redmine']['install_directory']}/redmine";
hostname = node['redmine']['hostname']
dbname = node['redmine']['postgresql']['database']

package 'libpq-dev'
package 'libmagick-dev'
package 'libmagickwand-dev'

# --- Create Redmine system user ---
user usr do
  comment 'Redmine User'
  home "/home/#{usr}"
  shell '/bin/bash'
  supports :manage_home=>true
end

# --- Download Redmine
directory downloadDir do
  owner usr
  group usr
  mode 00755
  action :create
end

remote_file "#{downloadDir}/#{redmineZipFile}" do
  owner usr
  group usr
  source node['redmine']['download_url']
  action :create_if_missing
end

# --- Extract and link Redmine ---
execute "Extract Redmine" do
  cwd downloadDir
  user 'root'
  group 'root'
  command "unzip -qd #{node['redmine']['install_directory']} #{redmineZipFile}"
  not_if {File.exist?(redmineHome)}
  notifies :run, "execute[Create symlink and change owner]", :immediately
end

execute "Create symlink and change owner" do
  user 'root'
  group 'root'
  command <<-EOH
rm -rf #{node['redmine']['install_directory']}/redmine &&
ln -s #{redmineHome} #{redmineHomeLink}
  EOH
  action :nothing
  notifies :run, "execute[Register thin gem for installation]", :immediately
end

# --- Configure redmine database ---
template "#{redmineHome}/config/database.yml" do
  owner usr
  group usr
  source "redmine.database.config.erb"
  mode 01700
  variables({
    :database => dbname,
    :user => node['redmine']['postgresql']['user'],
    :password => node['redmine']['postgresql']['password']
  })
end

# --- Install Redmine ---
execute "Install bundler" do
  command "gem install bundler"
end

execute "Register thin gem for installation" do
  cwd redmineHome
  command 'echo "gem \'thin\'" >> Gemfile'
  action :nothing
end

execute "Install gems" do
  cwd redmineHome
  command "bundle install --without development test"
end

execute "Generate session store secret" do
  cwd redmineHome
  user usr
  group usr
  command "rake generate_secret_token"
end

execute "Create redmine postgres user '#{node['redmine']['postgresql']['user']}'" do
  user 'postgres'
  command "psql -U postgres -c \"CREATE USER #{node['redmine']['postgresql']['user']};\""
  not_if("psql -U postgres -c \"SELECT * FROM pg_user WHERE usename='#{node['redmine']['postgresql']['user']}';\" | grep #{node['redmine']['postgresql']['user']}", :user => 'postgres')
end

execute "Set postgres user password of '#{node['redmine']['postgresql']['user']}'" do
  user 'postgres'
  command "psql -U postgres -c \"ALTER ROLE #{node['redmine']['postgresql']['user']} ENCRYPTED PASSWORD '#{node['redmine']['postgresql']['password']}';\""
end

execute "Create database '#{dbname}'" do
  user 'postgres'
  command "createdb '#{dbname}' -O #{node['redmine']['postgresql']['user']} -E UTF8 -T template0"
  not_if("psql -c \"SELECT datname FROM pg_catalog.pg_database WHERE datname='#{dbname}';\" | grep '#{dbname}'", :user => 'postgres')
end

execute "Create database structure" do
  cwd redmineHome
  user usr
  group usr
  command "RAILS_ENV=production rake db:migrate"
end

execute "Insert default database data" do
  cwd redmineHome
  user usr
  group usr
  command "RAILS_ENV=production REDMINE_LANG=en rake redmine:load_default_data"
end

execute "Configure file system permissions" do
  cwd redmineHome
  command <<-EOH
chown -R #{usr}:#{usr} #{redmineHome}
chmod -R 755 files log tmp
  EOH
end

directory "#{redmineHome}/public/plugin_assets" do
  owner usr
  group usr
  mode 00755
  action :create
end

# --- Configure thin application server behind nginx ---
template "/etc/init.d/thin" do
  source "init.d.thin.erb"
  mode 00750
  variables({
    :user => usr
  })
end

directory "/etc/thin" do
  mode 01755
  action :create
end

template "/etc/thin/redmine" do
  source "redmine.thin.config.erb"
  user 'root'
  group usr
  mode 00740
  variables({
    :home => redmineHomeLink
  })
end

template "/etc/nginx/sites-available/#{hostname}" do
  source "nginx.redmine.vhost.erb"
  mode 00700
  variables({
    :home => redmineHome,
    :hostname => hostname
  })
end

link "/etc/nginx/sites-available/#{hostname}" do
  to "/etc/nginx/sites-enabled/#{hostname}"
end
