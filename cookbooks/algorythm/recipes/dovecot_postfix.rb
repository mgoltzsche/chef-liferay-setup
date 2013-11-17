package 'dovecot-postfix'
package 'postfix-ldap'

usr = 'vmail'
vmailDirectory = "/home/#{usr}"
domain = node['liferay']['hostname']
ldapHost = 'localhost'
ldapPort = 389
ldapSuffix = node['liferay']['hostname'].split('.').map{|dc| "dc=#{dc}"}.join(',')

# --- Create postfix virtual mail user ---
user usr do
  comment 'postfix virtual mail user'
  home "/home/#{usr}"
  shell '/bin/bash'
  uid 5000
  gid 5000
  supports :manage_home=>true
end

# --- Configure postfix ---
directory '/etc/postfix/ldap' do
  mode 00700
  action :create
end

template "/etc/postfix/master.cf" do
  source "postfix.master.cf.erb"
  mode 0644
end

template "/etc/postfix/dynamicmaps.cf" do
  source "postfix.dynamicmaps.cf.erb"
  mode 0644
end

template "/etc/postfix/main.cf" do
  source "postfix.main.cf.erb"
  mode 0644
  variables({
    :hostname => node['hostname'],
    :vmail_directory => vmailDirectory
  })
end

template "/etc/postfix/ldap/virtual_aliases.cf" do
  source "postfix.virtual_aliases.cf.erb"
  mode 0644
  variables({
    :host => ldapHost,
    :port => ldapPort,
    :suffix => ldapSuffix
  })
end

template "/etc/postfix/ldap/virtual_domains.cf" do
  source "postfix.virtual_domains.cf.erb"
  mode 0644
  variables({
    :host => ldapHost,
    :port => ldapPort,
    :suffix => ldapSuffix
  })
end

template "/etc/postfix/ldap/virtual_mailboxes.cf" do
  source "postfix.virtual_mailboxes.cf.erb"
  mode 0644
  variables({
    :host => ldapHost,
    :port => ldapPort,
    :suffix => ldapSuffix
  })
end


#execute "Configure postfix vhosts" do
#  command "echo '#{domain}' > /etc/postfix/vhosts"
#end

#execute "Configure postfix vmaps" do
#  command <<-EOH
#echo 'admin@#{domain}  #{domain}/admin/' > /etc/postfix/vmaps &&
#postmap /etc/postfix/vmaps
#  EOH
#end

# --- Configure mail-stack-delivery ---
execute "Configure postfix mail-stack-delivery" do
  command "dpkg-reconfigure mail-stack-delivery"
end

# --- Configure dovecot ---
template "/etc/dovecot/dovecot.conf" do
  source "dovecot.conf.erb"
  mode 0600
  variables({
    :vmail_directory => vmailDirectory
  })
end



# --- Restart postfix & dovecot ---
service "postfix" do
  action :restart
end

service "dovecot" do
  action :restart
end
