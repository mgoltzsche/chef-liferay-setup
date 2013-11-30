package '389-ds-base'
package 'ldap-utils'

serverId = node['hostname']
listenhost = node['ldap']['listenhost']
port = node['ldap']['port']
domain = node['ldap']['domain']
suffix = ldapSuffix(domain)
dirmanager = node['ldap']['dirmanager']
dirmanager_password = node['ldap']['dirmanager_password']
adminCN = node['ldap']['admin_cn']
adminSN = node['ldap']['admin_sn']
adminGivenName = node['ldap']['admin_givenName']
ldapModifyParams = "-x -h localhost -p 389 -D cn='#{dirmanager}' -w #{dirmanager_password}"

# --- SSHA hash password ---
userPassword = ldapPassword(node['ldap']['admin_password'])


# --- Create instance if not exists ---
execute "Configure single instance" do
  command <<-EOH
echo "[General]
FullMachineName= #{node['hostname']}.#{node['domainname']}
SuiteSpotUserID= dirsrv
SuiteSpotGroup= dirsrv
ConfigDirectoryLdapURL= ldap://#{node['ldap']['hostname']}:389/o=NetscapeRoot
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
userPassword:: #{userPassword}
" | ldapmodify #{ldapModifyParams} -a
  EOH
  not_if "ldapsearch #{ldapModifyParams} -b 'cn=#{adminCN},ou=People,#{suffix}'"
end

# --- Restart dirsrv ---
service "dirsrv" do
  supports :restart => true
  action :nothing
end
