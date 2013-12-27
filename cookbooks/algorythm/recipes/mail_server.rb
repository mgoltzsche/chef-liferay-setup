package 'dovecot-postfix'
package 'postfix-ldap'
package 'dovecot-ldap'

machineFQN = "#{node['hostname']}.#{node['domainname']}"
usr = node['mail_server']['vmail_user']
vmailDirectory = node['mail_server']['vmail_directory']
ldapHost = node['ldap']['default']['hostname']
ldapInstances = node['ldap'].keys

# --- Create virtual mail user ---
user usr do
	comment 'Virtual mail user'
	shell '/bin/bash'
	home vmailDirectory
	uid 5000
	supports :manage_home => true
end

# --- Configure postfix ---
template '/etc/postfix/master.cf' do
	source 'postfix.master.cf.erb'
	owner 'root'
	group 'root'
	mode 0644
	notifies :restart, 'service[postfix]'
end

template '/etc/postfix/dynamicmaps.cf' do
	source 'postfix.dynamicmaps.cf.erb'
	owner 'root'
	group 'root'
	mode 0644
	notifies :restart, 'service[postfix]'
end

template '/etc/postfix/main.cf' do
	source 'postfix.main.cf.erb'
	owner 'root'
	group 'root'
	mode 0644
	variables({
		:machineFQN => machineFQN,
		:vmail_directory => vmailDirectory,
		:ldapInstances => ldapInstances
	})
	notifies :restart, 'service[postfix]'
end

directory '/etc/postfix/ldap' do
	owner 'root'
	group 'root'
	mode 00755
	action :create
end

node['ldap'].each do |instanceId, instance|
	ldapPort = instance['port']
	ldapSuffix = ldapSuffix(instance['domain'])
	ldapUser = node['mail_server']['ldap']['user']
	ldapUserDN = "cn=#{ldapUser},ou=Special Users,#{ldapSuffix}"
	ldapPassword = node['mail_server']['ldap']['password']
	ldapPasswordHashed = ldapPassword(ldapPassword)
	ldapModifyParams = "-x -h #{ldapHost} -p #{ldapPort} -D cn='#{instance['dirmanager']}' -w #{instance['dirmanager_password']}"

	directory "/etc/postfix/ldap/#{instanceId}" do
		owner 'root'
		group 'root'
		mode 00755
		action :create
	end

	execute "Register mailer account for #{instanceId} LDAP instance" do
		command <<-EOH
echo "dn: #{ldapUserDN}
objectClass: applicationProcess
objectClass: simpleSecurityObject
objectClass: top
cn: #{ldapUser}
description: Mail server
userPassword:: #{ldapPasswordHashed}
" | ldapmodify #{ldapModifyParams} -a
		EOH
		not_if "ldapsearch #{ldapModifyParams} -b '#{ldapUserDN}'"
	end

	template "/etc/postfix/ldap/#{instanceId}/virtual_aliases.cf" do
		source 'postfix.virtual_mailbox_query.cf.erb'
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
		notifies :restart, 'service[postfix]'
	end

	template "/etc/postfix/ldap/#{instanceId}/virtual_mailboxes.cf" do
		source 'postfix.virtual_mailbox_query.cf.erb'
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
		notifies :restart, 'service[postfix]'
	end

	template "/etc/postfix/ldap/#{instanceId}/virtual_senders.cf" do
		source 'postfix.virtual_mailbox_query.cf.erb'
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
		notifies :restart, 'service[postfix]'
	end
end

file '/etc/aliases' do
	owner 'root'
	group 'root'
	mode 0644
	content <<-EOH
postmaster: root
root: #{node['ldap']['default']['admin_cn']}@#{node['ldap']['default']['domain']}
	EOH
	notifies :run, 'execute[newaliases]', :immediately
end

execute 'newaliases' do
	user 'root'
	group 'root'
	command 'newaliases'
	action :nothing
	notifies :restart, 'service[postfix]'
end

# --- Configure mail-stack-delivery ---
execute 'Configure postfix mail-stack-delivery' do
	command 'dpkg-reconfigure mail-stack-delivery'
end

# --- Configure dovecot ---
template '/etc/dovecot/dovecot.conf' do
	source 'dovecot.conf.erb'
	owner 'root'
	group 'root'
	mode 0600
	variables({
		:vmail_directory => vmailDirectory,
		:vmail_user => usr,
		:ldapInstances => ldapInstances
	})
  notifies :restart, 'service[dovecot]'
end

node['ldap'].each do |instanceId, instance|
	ldapHost = instance['hostname']
	ldapPort = instance['port']
	ldapSuffix = ldapSuffix(instance['domain'])
	ldapUser = node['mail_server']['ldap']['user']
	ldapUserDN = "cn=#{ldapUser},ou=Special Users,#{ldapSuffix}"
	ldapPassword = node['mail_server']['ldap']['password']
	ldapPasswordHashed = ldapPassword(ldapPassword)
	ldapModifyParams = "-x -h #{ldapHost} -p #{ldapPort} -D cn='#{instance['dirmanager']}' -w #{instance['dirmanager_password']}"

	template "/etc/dovecot/dovecot-ldap-#{instanceId}.conf.ext" do
		source 'dovecot-ldap.conf.ext.erb'
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
		notifies :restart, 'service[dovecot]'
	end

	link "/etc/dovecot/dovecot-ldap-userdb-#{instanceId}.conf.ext" do
		to "/etc/dovecot/dovecot-ldap-#{instanceId}.conf.ext"
		notifies :restart, 'service[dovecot]'
	end
end

# --- Configure backup ---
template "#{node['backup']['install_directory']}/tasks/mail" do
	source 'backup.mail.erb'
	owner 'root'
	group 'root'
	mode 0744
	variables({
		:home => vmailDirectory,
		:user => usr
	})
end

# --- Restart postfix & dovecot ---
service 'postfix' do
	supports :restart => true
	action :nothing
end

service 'dovecot' do
	supports :restart => true
	action :nothing
end
