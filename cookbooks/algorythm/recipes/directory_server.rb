package '389-ds-base'
package 'ldap-utils'

listenhost = '0.0.0.0'
port = 389
dirman = 'manager'
dirman_pwd = 'maximum!'
userCN = 'devilopa'
userSN = 'Goltzsche'
userGivenName = 'Max'
userMailPrefix = 'admin'
maxOpenFiles = 4096
hostname = node['hostname']
domain = node['liferay']['hostname']
fullMachineName = "#{hostname}.#{domain}"
suffix = domain.split('.').map{|dc| "dc=#{dc}"}.join(',')

execute "Decrease TCP timeout" do
  command <<-EOH
echo "net.ipv4.tcp_keepalive_time = 600" >> /etc/sysctl.conf &&
sysctl -p
  EOH
  not_if('cat /etc/sysctl.conf | grep "net.ipv4.tcp_keepalive_time = 600"')
end

execute "Increase open file limit" do
  command <<-EOH
echo "*		 soft	 nofile		 #{maxOpenFiles}
*		 hard	 nofile		 #{maxOpenFiles}" >> /etc/security/limits.conf
  EOH
  not_if('cat /etc/security/limits.conf | grep "*		 soft	 nofile		 #{maxOpenFiles}"')
end

execute "Increase open file limit" do
  command <<-EOH
echo "*		 soft	 nofile		 #{maxOpenFiles}
*		 hard	 nofile		 #{maxOpenFiles}" >> /etc/security/limits.conf
  EOH
  not_if('cat /etc/security/limits.conf | grep "*		 soft	 nofile		 #{maxOpenFiles}"')
end

execute "Configure single instance" do
  command <<-EOH
echo "[General]
FullMachineName= #{fullMachineName}
SuiteSpotUserID= dirsrv
SuiteSpotGroup= dirsrv
ConfigDirectoryLdapURL= ldap://#{fullMachineName}:389/o=NetscapeRoot
ConfigDirectoryAdminID= admin
ConfigDirectoryAdminPwd= thepassword
AdminDomain= #{domain}

[slapd]
ServerIdentifier= #{hostname}
ServerPort= #{port}
Suffix= #{suffix}
RootDN= cn=#{dirman}
RootDNPwd= #{dirman_pwd}
" > /tmp/ds-config.inf &&
ulimit -n #{maxOpenFiles} &&
setup-ds -sf /tmp/ds-config.inf &&
rm -f /tmp/ds-config.inf
  EOH
  not_if {File.exist?("/etc/dirsrv/slapd-#{hostname}")}
  notifies :run, "execute[Configure TCPv4 localhost listening]", :immediately
end

execute "Configure TCPv4 localhost listening" do
  command <<-EOH
echo "dn: cn=config
changetype: modify
replace: nsslapd-listenhost
nsslapd-listenhost: #{listenhost}" > /tmp/nsslapd-listenhost.ldif &&
ldapmodify -a -x -h localhost -p 389 -D cn="#{dirman}" -w #{dirman_pwd} -f /tmp/nsslapd-listenhost.ldif &&
rm -f /tmp/nsslapd-listenhost.ldif
  EOH
  action :nothing
  notifies :run, "execute[Add person]", :immediately
end

execute "Add person" do
  command <<-EOH
echo "dn: cn=#{userCN},ou=People,#{suffix}
objectClass: simpleSecurityObject
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
objectClass: domainRelatedObject
cn: #{userCN}
sn: #{userSN}
givenName: #{userGivenName}
userPassword:: e3NzaGF9eGY2RkxXVzMvUExBNWlOOGl1MEpZbUlVV0dxb2MrSmwxUklxOXc9P
 Q==
mail: #{userMailPrefix}@#{domain}
associatedDomain: #{domain}
" > /tmp/admin_user.ldif &&
ldapmodify -a -x -h localhost -p 389 -D cn="#{dirman}" -w #{dirman_pwd} -f /tmp/admin_user.ldif &&
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
