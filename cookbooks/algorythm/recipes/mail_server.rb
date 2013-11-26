package 'dovecot-postfix'
package 'postfix-ldap'
package 'dovecot-ldap'

machineFQN = "#{node['hostname']}.#{node['domainname']}"
usr = node['mail_server']['vmail_user']
vmailDirectory = node['mail_server']['vmail_directory']
ldapHost = node['ldap']['hostname']
ldapPort = node['ldap']['port']
ldapSuffix = ldapSuffix(node['ldap']['domain'])
ldapUser = node['mail_server']['ldap']['user']
ldapUserDN = "cn=#{ldapUser},ou=Special Users,#{ldapSuffix}"
ldapPassword = node['mail_server']['ldap']['password']
ldapPasswordHashed = ldapPassword(ldapPassword)

# --- Create virtual mail user ---
user usr do
  comment 'Virtual mail user'
  shell '/bin/bash'
  home vmailDirectory
  uid 5000
  gid 5000
  supports :manage_home => true
end

# --- Create LDAP mail user ---
execute "Register LDAP mail account" do
  command <<-EOH
echo "dn: #{ldapUserDN}
objectClass: applicationProcess
objectClass: simpleSecurityObject
objectClass: top
cn: #{ldapUser}
description: Mail server
userPassword:: #{ldapPasswordHashed}
" | ldapmodify -a -x -h #{ldapHost} -p #{ldapPort} -D cn="#{node['ldap']['dirmanager']}" -w #{node['ldap']['dirmanager_password']}
  EOH
  not_if "ldapsearch -h #{ldapHost} -p #{ldapPort} -D cn='#{node['ldap']['dirmanager']}' -w #{node['ldap']['dirmanager_password']} -b '#{ldapUserDN}'"
end

# --- Configure postfix ---
directory '/etc/postfix/ldap' do
  owner 'root'
  group 'root'
  mode 00755
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
    :machineFQN => machineFQN,
    :vmail_directory => vmailDirectory
  })
end

template "/etc/postfix/ldap/virtual_domains.cf" do
  source "postfix.virtual_domains.cf.erb"
  owner 'root'
  group 'postfix'
  mode 0640
  variables({
    :host => ldapHost,
    :port => ldapPort,
    :suffix => ldapSuffix,
    :user => ldapUser,
    :password => ldapPassword
  })
end

template "/etc/postfix/ldap/virtual_aliases.cf" do
  source "postfix.virtual_mailbox_query.cf.erb"
  owner 'root'
  group 'postfix'
  mode 0640
  variables({
    :host => ldapHost,
    :port => ldapPort,
    :suffix => ldapSuffix,
    :user => ldapUser,
    :password => ldapPassword,
    :result_attribute => 'mailForwardingAddress'
  })
end

template "/etc/postfix/ldap/virtual_mailboxes.cf" do
  source "postfix.virtual_mailbox_query.cf.erb"
  owner 'root'
  group 'postfix'
  mode 0640
  variables({
    :host => ldapHost,
    :port => ldapPort,
    :suffix => ldapSuffix,
    :user => ldapUser,
    :password => ldapPassword,
    :result_attribute => "cn\nresult_filter = %s/"
  })
end

template "/etc/postfix/ldap/virtual_senders.cf" do
  source "postfix.virtual_mailbox_query.cf.erb"
  owner 'root'
  group 'postfix'
  mode 0640
  variables({
    :host => ldapHost,
    :port => ldapPort,
    :suffix => ldapSuffix,
    :user => ldapUser,
    :password => ldapPassword,
    :result_attribute => "cn"
  })
end

file "/etc/aliases" do
  owner 'root'
  group 'root'
  mode 0644
  content <<-EOH
postmaster: root
root: #{node['ldap']['admin_cn']}@#{node['ldap']['domain']}
  EOH
  notifies :run, "execute[newaliases]", :immediately
end

execute "newaliases" do
  user 'root'
  group 'root'
  command 'newaliases'
  action :nothing
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
    :port => ldapPort,
    :suffix => ldapSuffix,
    :user => ldapUser,
    :password => ldapPassword
  })
end

link "/etc/dovecot/dovecot-ldap-userdb.conf.ext" do
  to "/etc/dovecot/dovecot-ldap.conf.ext"
end

# --- Restart postfix & dovecot ---
service "postfix" do
  action :restart
end

service "dovecot" do
  action :restart
end
