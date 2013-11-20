package '389-ds-base'
package 'ldap-utils'

listenhost = node['ldap']['listenhost']
port = node['ldap']['port']
domain = node['ldap']['domain']
suffix = domain.split('.').map{|dc| "dc=#{dc}"}.join(',')
dirmanager = node['ldap']['dirmanager']
dirmanager_passwd = node['ldap']['dirmanager_password']
userCN = node['ldap']['user_cn']
userSN = node['ldap']['user_sn']
userGivenName = node['ldap']['user_givenName']

# --- SSHA hash password
hPwd = "e3NzaGF9eGY2RkxXVzMvUExBNWlOOGl1MEpZbUlVV0dxb2MrSmwxUklxOXc9P
 Q=="
hPwd = Base64.decode64(hPwd)
print hPwd+"\n"
hPwd = hPwd[6..hPwd.length]
print hPwd+"\n"
hPwd = Base64.decode64(hPwd)
print hPwd+"\n"
hSalt = hPwd[20..hPwd.length]
print "SALT: #{hSalt}, length: #{hSalt.length}\n"

password = node['ldap']['user_password']
chars = ('a'..'z').to_a + ('0'..'9').to_a
salt = Array.new(10, '').collect { chars[rand(chars.size)] }.join('')
salt = hSalt
password = '{ssha}' + Base64.encode64(Digest::SHA1.digest(salt+password)+salt).chomp!
#password = '->   ' + Digest::SHA1.digest(salt+password)+'/'+salt

print password+"\n"

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
nsslapd-listenhost: #{listenhost}" > /tmp/nsslapd-listenhost.ldif &&
ldapmodify -a -x -h localhost -p 389 -D cn="#{dirmanager}" -w #{dirmanager_passwd} -f /tmp/nsslapd-listenhost.ldif &&
rm -f /tmp/nsslapd-listenhost.ldif
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
" > /tmp/domain.ldif &&
ldapmodify -a -x -h localhost -p 389 -D cn="#{dirmanager}" -w #{dirmanager_passwd} -f /tmp/domain.ldif &&
rm -f /tmp/domain.ldif
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
userPassword:: e3NzaGF9eGY2RkxXVzMvUExBNWlOOGl1MEpZbUlVV0dxb2MrSmwxUklxOXc9P
 Q==
" > /tmp/admin_user.ldif &&
ldapmodify -a -x -h localhost -p 389 -D cn="#{dirmanager}" -w #{dirmanager_passwd} -f /tmp/admin_user.ldif &&
rm -f /tmp/admin_user.ldif
  EOH
  action :nothing
  notifies :restart, "service[dirsrv]", :immediately
end

# --- Restart dirsrv ---
service "dirsrv" do
  supports :restart => true
  action :nothing
end
