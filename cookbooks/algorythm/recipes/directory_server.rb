package '389-ds-base'
package 'ldap-utils'

listenhost = node['ldap']['listenhost']
port = node['ldap']['port']
domain = node['ldap']['domain']
suffix = ldapSuffix(domain)
dirmanager = node['ldap']['dirmanager']
dirmanager_passwd = node['ldap']['dirmanager_password']
userCN = node['ldap']['admin_cn']
userSN = node['ldap']['admin_sn']
userGivenName = node['ldap']['admin_givenName']

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
ServerIdentifier= #{node['hostname']}
ServerPort= #{port}
Suffix= #{suffix}
RootDN= cn=#{dirmanager}
RootDNPwd= #{dirmanager_passwd}
" > /tmp/ds-config.inf &&
ulimit -n #{node['max_open_files']} &&
setup-ds -sf /tmp/ds-config.inf &&
rm -f /tmp/ds-config.inf
  EOH
  not_if {File.exist?("/etc/dirsrv/slapd-#{node['hostname']}")}
  notifies :run, "execute[Configure TCPv4 localhost listening]", :immediately
end

execute "Configure TCPv4 localhost listening" do
  command <<-EOH
echo "dn: cn=config
changetype: modify
replace: nsslapd-listenhost
nsslapd-listenhost: #{listenhost}
" | ldapmodify -a -x -h localhost -p 389 -D cn="#{dirmanager}" -w #{dirmanager_passwd}
  EOH
  action :nothing
  notifies :run, "execute[Disable anonymous binds]", :immediately
end

execute "Disable anonymous binds" do
  command <<-EOH
echo "dn: cn=config
changetype: modify
replace: nsslapd-allow-anonymous-access
nsslapd-allow-anonymous-access: off
" | ldapmodify -a -x -h localhost -p 389 -D cn="#{dirmanager}" -w #{dirmanager_passwd}
  EOH
  action :nothing
  notifies :run, "execute[Register domain]", :immediately
end

# --- Add initial data to instance ---
execute "Register domain" do
  command <<-EOH
echo "dn: ou=Domains,#{suffix}
objectClass: organizationalUnit
objectClass: top
ou: Domains

dn: ou=#{domain},ou=Domains,#{suffix}
objectClass: domainRelatedObject
objectClass: organizationalUnit
objectClass: top
ou: #{domain}
associatedDomain: #{domain}
" | ldapmodify -a -x -h localhost -p 389 -D cn="#{dirmanager}" -w #{dirmanager_passwd}
  EOH
  action :nothing
  notifies :run, "execute[Register person]", :immediately
end

execute "Register person" do
  command <<-EOH
echo "dn: cn=#{userCN},ou=People,#{suffix}
objectClass: simpleSecurityObject
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
objectClass: mailRecipient
cn: #{userCN}
sn: #{userSN}
givenName: #{userGivenName}
mail: #{userCN}@#{domain}
userPassword:: #{userPassword}
" | ldapmodify -a -x -h localhost -p 389 -D cn="#{dirmanager}" -w #{dirmanager_passwd}
  EOH
  action :nothing
  notifies :restart, "service[dirsrv]", :immediately
end

# --- Restart dirsrv ---
service "dirsrv" do
  supports :restart => true
  action :nothing
end

# --- Install ldaputil ---
template '/usr/bin/ldaputil' do
  source 'ldaputil.erb'
  owner 'root'
  group 'root'
  mode 00700
end
