package '389-ds-base'
package 'ldap-utils'

node['ldap'].each do |serverId, instance|
	listenhost = instance['listenhost']
	port = instance['port']
	domain = instance['domain']
	suffix = ldapSuffix(domain)
	dirmanager = instance['dirmanager']
	dirmanager_password = instance['dirmanager_password']
	adminCN = instance['admin_cn']
	adminSN = instance['admin_sn']
	adminGivenName = instance['admin_givenName']
	adminPassword = instance['admin_password']
	ldapModifyParams = "-x -h localhost -p 389 -D cn='#{dirmanager}' -w #{dirmanager_password}"

	# --- Create instance if not exists ---
	execute 'Create instance' do
		command <<-EOH
echo "[General]
FullMachineName= #{node['hostname']}.#{node['domainname']}
SuiteSpotUserID= dirsrv
SuiteSpotGroup= dirsrv
ConfigDirectoryLdapURL= ldap://localhost:#{port}/o=NetscapeRoot
ConfigDirectoryAdminID= admin
ConfigDirectoryAdminPwd= thepassword
AdminDomain= #{node['domainname']}

[slapd]
ServerIdentifier= #{serverId}
ServerPort= #{port}
Suffix= #{suffix}
RootDN= cn=#{dirmanager}
RootDNPwd= #{dirmanager_password}
" > /tmp/ds-config.inf &&
ulimit -n #{node['max_open_files']} &&
setup-ds -sf /tmp/ds-config.inf &&
rm -f /tmp/ds-config.inf
		EOH
		not_if {File.exist?("/etc/dirsrv/slapd-#{serverId}")}
		notifies :run, 'execute[Configure instance]', :immediately
	end

	execute 'Configure instance' do
		command <<-EOH
echo "dn: cn=config
changetype: modify
replace: nsslapd-listenhost
nsslapd-listenhost: #{listenhost}

dn: cn=config
changetype: modify
replace: nsslapd-allow-anonymous-access
nsslapd-allow-anonymous-access: off
" | ldapmodify #{ldapModifyParams}
		EOH
		action :nothing
		notifies :run, 'execute[Remove default groups]', :immediately
	end

	execute "Remove default groups" do
		command <<-EOH
ldapsearch -x -h localhost -p 389 -D cn='dirmanager' -w password -b 'ou=Groups,dc=dev,dc=algorythm,dc=de' '(cn=*)' | grep -P '^dn:\\s' | while read -r groupDN; do
  echo $groupDN"\\nchangetype: delete" | ldapmodify #{ldapModifyParams}
done
		EOH
		action :nothing
		notifies :run, 'execute[Remove dirmanager Directory Administrators group membership]', :immediately
	end

	execute "Remove dirmanager Directory Administrators group membership" do # to avoid exception in external systems because dirmanager user does not exist in directory
		command <<-EOH
echo "dn: cn=Directory Administrators,#{suffix}
changetype: modify
delete: uniqueMember" | ldapmodify #{ldapModifyParams}
		EOH
		action :nothing
		notifies :restart, 'service[dirsrv]'
	end

	# --- Add initial data to instance ---
	execute 'Register domain unit' do
		command <<-EOH
echo "dn: ou=Domains,#{suffix}
objectClass: organizationalUnit
objectClass: top
ou: Domains
" | ldapmodify #{ldapModifyParams} -a
		EOH
		not_if "ldapsearch #{ldapModifyParams} -b 'ou=Domains,#{suffix}'"
	end

	execute 'Register domain' do
		command <<-EOH
echo "dn: ou=#{domain},ou=Domains,#{suffix}
objectClass: domainRelatedObject
objectClass: organizationalUnit
objectClass: top
ou: #{domain}
associatedDomain: #{domain}
" | ldapmodify #{ldapModifyParams} -a
		EOH
		not_if "ldapsearch #{ldapModifyParams} -b 'ou=#{domain},ou=Domains,#{suffix}'"
	end

	execute "Register admin person" do
		command <<-EOH
echo "dn: cn=#{adminCN},ou=People,#{suffix}
objectClass: simpleSecurityObject
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
objectClass: mailRecipient
cn: #{adminCN}
sn: #{adminSN}
givenName: #{adminGivenName}
mail: #{adminCN}@#{domain}
userPassword:: #{ldapPassword(adminPassword)}
" | ldapmodify #{ldapModifyParams} -a
		EOH
		not_if "ldapsearch #{ldapModifyParams} -b 'cn=#{adminCN},ou=People,#{suffix}'"
	end
end

# --- Configure config backup ---
template "#{node['backup']['install_directory']}/tasks/ldap" do
	source 'backup.ldap.erb'
	owner 'root'
	group 'root'
	mode 0744
end

# --- Restart dirsrv ---
service 'dirsrv' do
	supports :restart => true
	action :nothing
end
