hostname = node['redmine']['hostname']
usr = node['redmine']['user']
downloadDir = "/Downloads"
redmineDir = "#{node['redmine']['install_directory']}/redmine-#{node['redmine']['version']}"
redmineDirLink = "#{node['redmine']['install_directory']}/redmine"
redmineHomeDir = node['redmine']['home']
redmineVersion = node['redmine']['version']
dbname = node['redmine']['postgresql']['database']
backlogsDir = "#{redmineDir}/plugins/redmine_backlogs"
backlogsVersion = node['redmine']['backlogs_version']
mailServerHost = node['mail_server']['hostname']
ldapAuthSourceName = 'Local LDAP Server'
ldapHost = node['ldap']['hostname']
ldapPort = node['ldap']['port']
ldapSuffix = ldapSuffix(node['ldap']['domain'])
ldapUser = node['redmine']['ldap']['user']
ldapUserDN = "cn=#{ldapUser},ou=Special Users,#{ldapSuffix}"
ldapPassword = node['redmine']['ldap']['password']
ldapPasswordHashed = ldapPassword(ldapPassword)
ldapDomainDN = "ou=#{hostname},ou=Domains,#{ldapSuffix}"
systemMailPrefix = node['redmine']['system_mail_prefix']
adminCN = node['ldap']['admin_cn']
adminLastname = node['ldap']['admin_sn']
adminFirstname = node['ldap']['admin_givenName']
adminEmail = "#{adminCN}@#{node['ldap']['domain']}"
systemEmail = "#{systemMailPrefix}@#{hostname}"
ldapModifyParams = "-x -h #{ldapHost} -p #{ldapPort} -D cn='#{node['ldap']['dirmanager']}' -w #{node['ldap']['dirmanager_password']}"

package 'libpq-dev'
package 'libmagick-dev'
package 'libmagickwand-dev'
package 'git'

# --- Create Redmine system user ---
user usr do
  comment 'Redmine User'
  shell '/bin/bash'
  home redmineHomeDir
  supports :manage_home => true
end

# --- Create Redmine LDAP user ---
execute "Register Redmine LDAP account" do
  command <<-EOH
echo "dn: #{ldapUserDN}
objectClass: applicationProcess
objectClass: simpleSecurityObject
objectClass: top
objectClass: mailRecipient
cn: #{ldapUser}
description: Redmine Project Management System
mail: #{systemEmail}
mailForwardingAddress: #{adminEmail}
userPassword:: #{ldapPasswordHashed}
" | ldapmodify #{ldapModifyParams}
  EOH
  not_if "ldapsearch #{ldapModifyParams} -b '#{ldapUserDN}'"
end

# --- Register Redmine hostname in LDAP ---
execute "Register Redmine hostname in LDAP" do
  command <<-EOH
echo "dn: #{ldapDomainDN}
objectClass: top
objectClass: organizationalUnit
objectClass: domainRelatedObject
ou: #{hostname}
associatedDomain: #{hostname}
" | ldapmodify #{ldapModifyParams}
  EOH
  not_if "ldapsearch #{ldapModifyParams} -b '#{ldapDomainDN}'"
end

# --- Download Redmine & Backlogs plugin ---
directory downloadDir do
  mode 01755
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
cp -R #{downloadDir}/redmine #{redmineDir} &&
rm -rf #{redmineDir}/files
  EOH
  not_if {File.exist?(redmineDir)}
end

execute "Checkout and copy Redmine Backlogs to plugins directory" do
  cwd "#{downloadDir}/redmine_backlogs"
  command <<-EOH
git fetch --tags origin &&
git checkout #{backlogsVersion} &&
cp -R #{downloadDir}/redmine_backlogs #{backlogsDir}
  EOH
  not_if {File.exist?(backlogsDir)}
end

directory "#{redmineDir}/public/plugin_assets" do
  mode 00755
end

link redmineDirLink do
  to redmineDir
end

# --- Install required gems ---
execute "Install bundler" do
  command "gem install bundler"
  not_if('ls $(/usr/local/rvm/bin/rvm gemdir)/bin | grep bundle')
end

execute "Install required gems" do
  cwd redmineDir
  command "bundle install --without development test"
end

execute "Install required Backlog plugin gems" do
  cwd backlogsDir
  command "bundle install --without development test"
end

# --- Change file system permissions ---
execute "Configure file system permissions" do
  cwd redmineDir
  command <<-EOH
chown -R #{usr}:#{usr} #{redmineDir} &&
chmod -R 755 log tmp public/plugin_assets
  EOH
end

# --- Initially generate session store secret ---
execute "Generate session store secret" do
  cwd redmineDir
  user usr
  group usr
  command "rake generate_secret_token"
  not_if {File.exist?("#{redmineDir}/config/database.yml")}
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
template "#{redmineDir}/config/database.yml" do
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

# --- Configure Redmine home dir & SMPT connection ---
template "#{redmineDir}/config/configuration.yml" do
  owner usr
  group usr
  source "redmine.configuration.yml.erb"
  mode 00400
  variables({
    :homeDir => redmineHomeDir,
    :mailServerHost => mailServerHost,
    :mailServerUser => ldapUser,
    :mailServerPassword => ldapPassword
  })
end

# --- Create/Migrate database structures ---
execute "Create/Migrate database structure" do
  cwd redmineDir
  user usr
  group usr
  command "export RAILS_ENV=production; rake db:migrate"
end

execute "Insert default data" do
  cwd redmineDir
  user usr
  group usr
  command "export RAILS_ENV=production; export REDMINE_LANG=en; rake redmine:load_default_data"
end

# --- Configure settings ---
settings = {
  'host_name'     => hostname,
  'mail_from'     => systemEmail,
  'emails_footer' => "You have received this notification because you have either subscribed to it, or are involved in it.\\r\\nTo change your notification preferences, please click here: https://#{hostname}/my/account"
}

settings.keys.each do |key|
  value = settings[key]

  execute "Create #{key} setting" do
    user 'postgres'
    command "psql -d #{dbname} -c \"INSERT INTO settings(name) VALUES('#{key}');\""
    not_if("psql -d #{dbname} -c \"SELECT name FROM settings WHERE name='#{key}';\" | grep '#{key}'", :user => 'postgres')
  end

  execute "Set #{key} setting" do
    user 'postgres'
    command "psql -d #{dbname} -c \"UPDATE settings SET value='#{value}' WHERE name='#{key}';\""
    not_if("psql -d #{dbname} -c \"SELECT name FROM settings WHERE name='#{key}' AND value='#{value}';\" | grep '#{key}'", :user => 'postgres')
  end
end

# --- Configure LDAP connection ---
execute "Add LDAP auth source" do
  user 'postgres'
  command "psql -d #{dbname} -c \"INSERT INTO auth_sources(type,name,filter,timeout) VALUES('AuthSourceLdap', '#{ldapAuthSourceName}', '', 30);\""
  not_if("psql -d #{dbname} -c \"SELECT name FROM auth_sources WHERE name='#{ldapAuthSourceName}';\" | grep '#{ldapAuthSourceName}'", :user => 'postgres')
end

execute "Update LDAP auth source" do
  user 'postgres'
  command <<-EOH
psql -d #{dbname} -c "UPDATE auth_sources SET host='#{ldapHost}',port='#{ldapPort}',account='cn=#{ldapUser},ou=Special Users,#{ldapSuffix}',account_password='#{ldapPassword}',base_dn='#{ldapSuffix}',attr_login='cn',attr_firstname='givenName',attr_lastname='sn',attr_mail='mail',onthefly_register='t',tls='f' WHERE name='#{ldapAuthSourceName}';"
  EOH
end

# --- Update default Redmine admin account ---
execute "Update admin user" do
  user 'postgres'
  command "psql -d #{dbname} -c \"UPDATE users SET login='#{adminCN}',mail='#{adminEmail}',firstname='#{adminFirstname}',lastname='#{adminLastname}',auth_source_id=(SELECT id FROM auth_sources WHERE name='#{ldapAuthSourceName}'),hashed_password='',salt=NULL WHERE login='admin';\""
  not_if("psql -d #{dbname} -c \"SELECT login FROM users WHERE login='#{adminCN}' AND auth_source_id IS NOT NULL;\" | grep '#{adminCN}'", :user => 'postgres')
end

# --- Install Redmine backlogs plugin ---
execute "Install Redmine Backlogs plugin" do
  user usr
  group usr
  cwd redmineDir
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

# --- Configure backup ---
template "#{node['backup']['install_directory']}/scripts/backup-redmine.sh" do
  source "backup-redmine.sh.erb"
  owner 'root'
  group 'root'
  mode 00700
  variables({
    :dir => redmineDir,
    :homeDir => redmineHomeDir
  })
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
end

template "/etc/thin/redmine" do
  source "redmine.thin.config.erb"
  user 'root'
  group usr
  mode 00740
  variables({
    :home => redmineDirLink
  })
end

template "/etc/nginx/sites-available/#{hostname}" do
  source "redmine.nginx.vhost.erb"
  mode 00700
  variables({
    :home => redmineDir,
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
# Account: cn=dirmanager
# Password: ***
# Base DN: dc=algorythm,dc=de
# On-the-fly-Userimport: yes
# Login attribute: cn
# firstname attribute: givenName
# lastname attribute: sn
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
