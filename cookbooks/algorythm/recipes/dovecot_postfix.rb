package 'dovecot-postfix'
package 'postfix-ldap'
package 'dovecot-ldap'

usr = 'vmail'
vmailDirectory = "/var/vmail"
domain = node['liferay']['hostname']
ldapHost = 'localhost'
ldapSuffix = node['liferay']['hostname'].split('.').map{|dc| "dc=#{dc}"}.join(',')
dirman = 'manager'
dirman_passwd = 'maximum!'

# --- Create postfix virtual mail user ---
user usr do
  comment 'postfix virtual mail user'
  shell '/bin/bash'
  uid 5000
  gid 5000
  supports :manage_home=>true
end

# --- Configure postfix ---
directory '/etc/postfix/ldap' do
  owner 'root'
  group 'root'
  mode 00755
  action :create
end

directory vmailDirectory do
  owner usr
  group usr
  mode 00744
  action :create
end

template "/etc/postfix/master.cf" do
  source "postfix.master.cf.erb"
  owner 'root'
  group 'root'
  mode 0644
end

template "/etc/postfix/dynamicmaps.cf" do
  source "postfix.dynamicmaps.cf.erb"
  owner 'root'
  group 'root'
  mode 0644
end

template "/etc/postfix/main.cf" do
  source "postfix.main.cf.erb"
  owner 'root'
  group 'root'
  mode 0644
  variables({
    :hostname => node['hostname'],
    :domain => node['liferay']['hostname'],
    :vmail_directory => vmailDirectory
  })
end

template "/etc/postfix/ldap/virtual_aliases.cf" do
  source "postfix.virtual_aliases.cf.erb"
  owner 'root'
  group 'root'
  mode 0644
  variables({
    :host => ldapHost,
    :suffix => ldapSuffix
  })
end

template "/etc/postfix/ldap/virtual_domains.cf" do
  source "postfix.virtual_domains.cf.erb"
  owner 'root'
  group 'root'
  mode 0644
  variables({
    :host => ldapHost,
    :suffix => ldapSuffix
  })
end

template "/etc/postfix/ldap/virtual_mailboxes.cf" do
  source "postfix.virtual_mailboxes.cf.erb"
  owner 'root'
  group 'root'
  mode 0644
  variables({
    :host => ldapHost,
    :suffix => ldapSuffix
  })
end

# --- Configure mail-stack-delivery ---
execute "Configure postfix mail-stack-delivery" do
  command "dpkg-reconfigure mail-stack-delivery"
end

# --- Configure dovecot ---
template "/etc/dovecot/dovecot.conf" do
  source "dovecot.conf.erb"
  owner 'root'
  group 'root'
  mode 0600
  variables({
    :vmail_directory => vmailDirectory
  })
end

template "/etc/dovecot/dovecot-ldap.conf.ext" do
  source "dovecot-ldap.conf.ext.erb"
  owner 'root'
  group 'root'
  mode 0600
  variables({
    :host => ldapHost,
    :suffix => ldapSuffix,
    :dirman => dirman,
    :dirman_passwd => dirman_passwd
  })
end

# --- Restart postfix & dovecot ---
service "postfix" do
  action :restart
end

service "dovecot" do
  action :restart
end
