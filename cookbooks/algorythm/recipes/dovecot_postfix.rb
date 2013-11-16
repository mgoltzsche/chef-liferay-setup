package 'dovecot-postfix'

usr = 'vmail'
vmailDirectory = '/home/vmail'
hostname = node['liferay']['hostname']

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
execute "Configure postfix initially" do
  command <<-EOH
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
debconf-set-selections <<< "postfix postfix/mailname string #{hostname}"
dpkg-reconfigure postfix
  EOH
end

template "/etc/postfix/main.cf" do
  source "postfix.main.cf.erb"
  mode 0600
  variables({
    :hostname => hostname,
    :vmail_directory => vmailDirectory
  })
end

execute "Configure postfix mail-stack-delivery" do
  command "dpkg-reconfigure mail-stack-delivery"
end

execute "Configure postfix vhosts" do
  command "echo '#{hostname}' > /etc/postfix/vhosts"
end

execute "Configure postfix vmaps" do
  command <<-EOH
echo 'admin@#{hostname}	#{hostname}/admin/' > /etc/postfix/vmaps &&
postmap /etc/postfix/vmaps
  EOH
end

# --- Configure dovecot ---
template "/etc/dovecot/dovecot.conf" do
  source "dovecot.conf.erb"
  mode 0600
  variables({
    :vmail_directory => vmailDirectory
  })
end

# --- Restart postfix ---
service "postfix" do
  action :restart
end
