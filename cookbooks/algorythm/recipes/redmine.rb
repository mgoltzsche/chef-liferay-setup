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
  notifies :create, "directory[#{redmineHome}/public/plugin_assets]", :immediately
end

directory "#{redmineHome}/public/plugin_assets" do
  owner usr
  group usr
  mode 00755
  action :nothing
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
  notifies :run, "execute[Configure file system permissions]", :immediately
end

execute "Configure file system permissions" do
  cwd redmineHome
  command <<-EOH
chown -R #{usr}:#{usr} #{redmineHome}
chmod -R 755 files log tmp
  EOH
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

link "/etc/nginx/sites-enabled/#{hostname}" do
  to "/etc/nginx/sites-available/#{hostname}"
end

# Install Redmine backlogs plugin
package 'git'

execute "Download Redmine backlogs plugin" do
  user usr
  group usr
  cwd "#{downloadDir}"
  command "git clone git://github.com/backlogs/redmine_backlogs.git"
  not_if {File.exist?("#{downloadDir}/redmine_backlogs")}
end

execute "Install redmine backlogs plugin" do
  user usr
  group usr
  cwd "#{downloadDir}/redmine_backlogs"
  command <<-EOH
git checkout #{node['redmine']['backlogs_version']} &&
cp -R . #{redmineHome}/plugins/redmine_backlogs &&
cd #{redmineHome}/plugins/redmine_backlogs &&
export RAILS_ENV=production &&
rake db:migrate &&
rake tmp:cache:clear &&
rake tmp:sessions:clear
# bundle exec rake redmine:backlogs:install param1=...
  EOH
  not_if {File.exist?("#{redmineHome}/plugins/redmine_backlogs")}
  notifies :run, "execute[Configure file system permissions]", :immediately
end

# Restart thin & nginx
service "thin" do
  action :restart
end

service "nginx" do
  action :restart
end


# Example LDAP config:
# Name: LDAP (local)
# Host: localhost
# Port: 389
# Account: cn=manager
# Password: ***
# Base DN: dc=algorythm,dc=de
# On-the-fly-Userimport: yes
# Member name attribute: cn
# first name attribute: givenName
# name attribute: sn
# email attribute: mail
