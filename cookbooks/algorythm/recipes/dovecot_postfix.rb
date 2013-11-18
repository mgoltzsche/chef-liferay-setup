package 'dovecot-postfix'
package 'postfix-ldap'
package 'dovecot-ldap'

usr = 'vmail'
vmailDirectory = "/var/vmail"
domain = node['liferay']['hostname']
ldapHost = 'localhost'
ldapSuffix = node['liferay']['hostname'].split('.').map{|dc| "dc=#{dc}"}.join(',')
ldapUser = 'manager'
ldapPassword = 'maximum!'

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

template "/etc/postfix/ldap/virtual_domains.cf" do
  source "postfix.virtual_domains.cf.erb"
  owner 'root'
  group 'root'
  mode 0644
  variables({
    :host => ldapHost,
    :suffix => ldapSuffix,
    :user => ldapUser,
    :password => ldapPassword
  })
end

template "/etc/postfix/ldap/virtual_aliases.cf" do
  source "postfix.virtual_mailbox_query.cf.erb"
  owner 'root'
  group 'root'
  mode 0644
  variables({
    :host => ldapHost,
    :suffix => ldapSuffix,
    :user => ldapUser,
    :password => ldapPassword,
    :result_attribute => 'mailForwardingAddress'
  })
end

template "/etc/postfix/ldap/virtual_mailboxes.cf" do
  source "postfix.virtual_mailbox_query.cf.erb"
  owner 'root'
  group 'root'
  mode 0644
  variables({
    :host => ldapHost,
    :suffix => ldapSuffix,
    :user => ldapUser,
    :password => ldapPassword,
    :result_attribute => "cn\nresult_filter = %s/"
  })
end

template "/etc/postfix/ldap/virtual_senders.cf" do
  source "postfix.virtual_mailbox_query.cf.erb"
  owner 'root'
  group 'root'
  mode 0644
  variables({
    :host => ldapHost,
    :suffix => ldapSuffix,
    :user => ldapUser,
    :password => ldapPassword,
    :result_attribute => "cn"
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
    :vmail_directory => vmailDirectory,
    :vmail_user => usr
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
    :user => ldapUser,
    :password => ldapPassword
  })
end

# --- Restart postfix & dovecot ---
service "postfix" do
  action :restart
end

service "dovecot" do
  action :restart
end
