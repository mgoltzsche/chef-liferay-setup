hostname = node['redmine']['hostname']
usr = node['redmine']['user']
downloadDir = "/Downloads"
redmineHome = "#{node['redmine']['install_directory']}/redmine-#{node['redmine']['version']}";
redmineHomeLink = "#{node['redmine']['install_directory']}/redmine";
redmineVersion = node['redmine']['version']
dbname = node['redmine']['postgresql']['database']
backlogsHome = "#{redmineHome}/plugins/redmine_backlogs"
backlogsVersion = node['redmine']['backlogs_version']
mailServerHost = node['mail_server']['hostname']
mailServerUser = node['ldap']['system_mail_user']
mailServerPassword = node['ldap']['system_mail_password']

package 'libpq-dev'
package 'libmagick-dev'
package 'libmagickwand-dev'
package 'git'

# --- Create Redmine system user ---
user usr do
  comment 'Redmine User'
  shell '/bin/bash'
  supports :manage_home=>true
end

# --- Download Redmine & Backlogs plugin ---
directory downloadDir do
  mode 00755
  action :create
end

execute "Clone Redmine git repository" do
  cwd "#{downloadDir}"
  command "git clone git://github.com/redmine/redmine.git"
  not_if {File.exist?("#{downloadDir}/redmine")}
end

execute "Clone Redmine Backlogs plugin git repository" do
  cwd "#{downloadDir}"
  command "git clone git://github.com/backlogs/redmine_backlogs.git"
  not_if {File.exist?("#{downloadDir}/redmine_backlogs")}
end

# --- Checkout, copy and link Redmine installation ---
execute "Checkout and copy Redmine to installation directory" do
  cwd "#{downloadDir}/redmine"
  command <<-EOH
git fetch --tags origin &&
git checkout #{redmineVersion} &&
cp -R #{downloadDir}/redmine #{redmineHome}
  EOH
  not_if {File.exist?(redmineHome)}
end

execute "Checkout and copy Redmine Backlogs to plugins directory" do
  cwd "#{downloadDir}/redmine_backlogs"
  command <<-EOH
git fetch --tags origin &&
git checkout #{backlogsVersion} &&
cp -R #{downloadDir}/redmine_backlogs #{backlogsHome}
  EOH
  not_if {File.exist?(backlogsHome)}
end

directory "#{redmineHome}/public/plugin_assets" do
  mode 00755
  action :create
end

execute "Create/Update symlink and change owner" do
  command <<-EOH
rm -rf #{redmineHomeLink} &&
ln -s #{redmineHome} #{redmineHomeLink} &&
chown -R #{usr}:#{usr} #{redmineHome}
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

execute "Set redmine postgres user password" do
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
  source "redmine.database.yml.erb"
  mode 00400
  variables({
    :database => dbname,
    :user => node['redmine']['postgresql']['user'],
    :password => node['redmine']['postgresql']['password']
  })
end

# --- Configure Redmine SMPT connection ---
template "#{redmineHome}/config/configuration.yml" do
  owner usr
  group usr
  source "redmine.configuration.yml.erb"
  mode 00400
  variables({
    :mailServerHost => mailServerHost,
    :mailServerUser => mailServerUser,
    :mailServerPassword => mailServerPassword
  })
end

# --- Create/Migrate database structures ---
execute "Create/Migrate database structure" do
  cwd redmineHome
  user usr
  group usr
  command "export RAILS_ENV=production; rake db:migrate"
end

execute "Insert default data" do
  cwd redmineHome
  user usr
  group usr
  command "export RAILS_ENV=production; export REDMINE_LANG=en; rake redmine:load_default_data"
end

# --- Install Redmine backlogs plugin ---
execute "Install Redmine Backlogs plugin" do
  user usr
  group usr
  cwd redmineHome
  command <<-EOH
export RAILS_ENV=production;
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

# --- Restart thin & nginx ---
service "thin" do
  action :restart
end

service "nginx" do
  action :restart
end


## Example LDAP config:
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

## Backup like this (files + sql):
# cp -R $REDMINE_HOME/files $BACKUP/files
# su postgres -c "pg_dump -U redmine -h localhost -Fp --file=$BACKUP/redmine.sqlc

## Import backup like this (files + sql):
# rm -rf $REDMINE_HOME/files;
# cp -R $BACKUP/files $REDMINE_HOME/files &&
# chown -R redmine:redmine $REDMINE_HOME/files &&
# su postgres -c "psql redmine < $BACKUP/redmine.sqlc"
## Execute the following to migrate the database afterwards:
# su redmine -c "PATH=$PATH:$(/usr/local/rvm/bin/rvm gemdir)/bin:/usr/local/rvm/bin; export RAILS_ENV=production; rake db:migrate; rake redmine:backlogs:install"
