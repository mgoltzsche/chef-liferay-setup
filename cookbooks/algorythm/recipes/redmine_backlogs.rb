usr = node['redmine']['user']
downloadDir = "/home/#{usr}/Downloads"
redmineZipFile = File.basename(URI.parse(node['redmine']['download_url']).path)
redmineExtractionDir = redmineZipFile.gsub(/(.*)\.zip/, '\1')
redmineHome = "#{node['redmine']['install_directory']}/#{redmineExtractionDir}";
redmineHomeLink = "#{node['redmine']['install_directory']}/redmine";
hostname = node['redmine']['hostname']
dbname = node['redmine']['postgresql']['database']
backlogsHome = "#{redmineHome}/plugins/redmine_backlogs"

package 'libpq-dev'
package 'libmagick-dev'
package 'libmagickwand-dev'
package 'git'

# --- Create Redmine system user ---
user usr do
  comment 'Redmine User'
  home "/home/#{usr}"
  shell '/bin/bash'
  supports :manage_home=>true
end

# --- Download Redmine & Backlogs plugin
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

execute "Download Redmine Backlogs plugin repository" do
  user usr
  group usr
  cwd "#{downloadDir}"
  command "git clone git://github.com/backlogs/redmine_backlogs.git"
  not_if {File.exist?("#{downloadDir}/redmine_backlogs")}
end

# --- Copy and link Redmine installation ---
execute "Put Redmine in place" do
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
end

execute "Put Redmine Backlogs plugin in place" do
  user usr
  group usr
  cwd "#{downloadDir}/redmine_backlogs"
  command <<-EOH
git checkout #{node['redmine']['backlogs_version']} &&
cp -R . #{backlogsHome}
  EOH
  not_if {File.exist?(backlogsHome)}
end

execute "Create symlink" do
  user 'root'
  group 'root'
  command <<-EOH
rm -rf #{node['redmine']['install_directory']}/redmine &&
ln -s #{redmineHome} #{redmineHomeLink}
  EOH
end

# --- Install required gems ---
execute "Install bundler" do
  command "gem install bundler"
end

execute "Install required gems" do
  cwd redmineHome
  command "bundle install --without development test"
end

execute "Install required Backlog plugin gems" do
  cwd backlogsHome
  command "bundle install --without development test"
end

# --- Change file system permissions ---
execute "Configure file system permissions" do
  cwd redmineHome
  command <<-EOH
chown -R #{usr}:#{usr} #{redmineHome} &&
chmod -R 755 files log tmp public/plugin_assets
  EOH
end

# --- Initially generate session store secret ---
execute "Generate session store secret" do
  cwd redmineHome
  user usr
  group usr
  command "rake generate_secret_token"
  not_if {File.exist?("#{redmineHome}/config/database.yml")}
end

# --- Create postgresql database + user ---
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

# --- Configure Redmine database connection ---
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

# --- Create/Migrate database structures ---
execute "Create/Migrate database structure" do
  cwd redmineHome
  user usr
  group usr
  command "RAILS_ENV=production rake db:migrate"
end

execute "Insert default data" do
  cwd redmineHome
  user usr
  group usr
  command "RAILS_ENV=production REDMINE_LANG=en rake redmine:load_default_data"
end

# Install Redmine backlogs plugin
execute "Install Redmine Backlogs plugin" do
  user usr
  group usr
  cwd redmineHome
  command <<-EOH
export RAILS_ENV=production;
rake db:migrate &&
rake tmp:cache:clear &&
rake tmp:sessions:clear &&
rake redmine:backlogs:install \
	story_trackers=feature \
	task_tracker=task \
	corruptiontest=true \
	labels=true
  EOH
end

# --- Configure thin application server to run Redmine behind nginx ---
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
