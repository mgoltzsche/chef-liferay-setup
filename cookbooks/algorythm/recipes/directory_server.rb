package '389-ds-base'
package 'ldap-utils'

# --- Stop dirsrv ---
service 'dirsrv' do
	action :stop
end

node['ldap'].each do |instanceId, instance|
	listenhost = instance['listenhost']
	port = instance['port']
	domain = instance['domain']
	suffix = ldapSuffix(domain)
	dirmanager = instance['dirmanager']
	dirmanagerPasswordPlain = instance['dirmanager_password']
	dirmanagerPassword = Base64.decode64(ldapPassword(dirmanagerPasswordPlain))
	adminCN = instance['admin_cn']
	adminSN = instance['admin_sn']
	adminGivenName = instance['admin_givenName']
	adminPassword = ldapPassword(instance['admin_password'])
	ldapModifyParams = "-x -h localhost -p #{port} -D cn='#{dirmanager}' -w #{dirmanagerPasswordPlain}"

	execute "Create #{instanceId} instance" do
		command <<-EOH
echo "[General]
FullMachineName= #{node['hostname']}.#{node['domainname']}
SuiteSpotUserID= dirsrv
SuiteSpotGroup= dirsrv
AdminDomain= #{node['domainname']}

[slapd]
ServerIdentifier= #{instanceId}
ServerPort= #{port}
Suffix= #{suffix}
RootDN= cn=#{dirmanager}
RootDNPwd= #{dirmanagerPassword}
" > /tmp/ds-config.inf &&
ulimit -n #{node['max_open_files']} &&
setup-ds -sf /tmp/ds-config.inf
STATUS=$?
rm -f /tmp/ds-config.inf
exit $STATUS
		EOH
		not_if {File.exist?("/etc/dirsrv/slapd-#{instanceId}")}
		notifies :run, "execute[Configure #{instanceId} instance]", :immediately
	end

	execute "Configure #{instanceId} instance" do
		command <<-EOH
echo "dn: cn=config
changetype: modify
replace: nsslapd-listenhost
nsslapd-listenhost: #{listenhost}

dn: cn=config
changetype: modify
replace: nsslapd-allow-anonymous-access
nsslapd-allow-anonymous-access: off

dn: cn=config
changetype: modify
replace: passwordStorageScheme
passwordStorageScheme: SSHA512

dn: cn=config
changetype: modify
replace: nsslapd-rootpwstoragescheme
nsslapd-rootpwstoragescheme: SSHA512
" | ldapmodify #{ldapModifyParams}
		EOH
		action :nothing
		notifies :run, "execute[Remove default groups from #{instanceId} instance]", :immediately
	end

	execute "Remove default groups from #{instanceId} instance" do
		command <<-EOH
ldapsearch -x -h localhost -p 389 -D cn='dirmanager' -w password -b 'ou=Groups,#{suffix}' '(cn=*)' | grep -P '^dn:\\s' | while read -r groupDN; do
  echo $groupDN"\\nchangetype: delete" | ldapmodify #{ldapModifyParams}
done
		EOH
		action :nothing
		notifies :run, "execute[Remove dirmanager Directory Administrators group membership from #{instanceId} instance]", :immediately
	end

	execute "Remove dirmanager Directory Administrators group membership from #{instanceId} instance" do # to avoid exception in external systems because dirmanager user does not exist in directory
		command <<-EOH
echo "dn: cn=Directory Administrators,#{suffix}
changetype: modify
delete: uniqueMember" | ldapmodify #{ldapModifyParams}
		EOH
		action :nothing
		notifies :restart, 'service[dirsrv]'
	end

	# --- (Re)set directory manager password ---
#	if File.exist?("/etc/dirsrv/slapd-#{instanceId}/dse.ldif")
#		file "Set #{instanceId} instance manager password" do
#			path "/etc/dirsrv/slapd-#{instanceId}/dse.ldif"
#			content File.read("/etc/dirsrv/slapd-#{instanceId}/dse.ldif").gsub!(/(nsslapd-rootpw:\s{[\w]*}([^\s]+|\n\s)+)/, "nsslapd-rootpw: #{dirmanagerPassword}")
#			backup false
#			notifies :restart, 'service[dirsrv]', :immediately
#		end
#	end

	# --- Add initial data to instance ---
	execute "Register domain unit for #{instanceId} instance" do
		command <<-EOH
echo "dn: ou=Domains,#{suffix}
objectClass: organizationalUnit
objectClass: top
ou: Domains
" | ldapmodify #{ldapModifyParams} -a
		EOH
		not_if "ldapsearch #{ldapModifyParams} -b 'ou=Domains,#{suffix}'"
	end

	execute "Register domain #{domain} for #{instanceId} instance" do
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

	execute "Register admin person for #{instanceId} instance" do
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
userPassword:: #{adminPassword}
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
