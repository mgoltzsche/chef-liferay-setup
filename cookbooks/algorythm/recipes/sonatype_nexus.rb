usr = node['liferay']['user']
downloadDir = "/Downloads"
version = node['nexus']['version']
nexusWarFile = "#{downloadDir}/nexus-#{version}.war"
nexusExtractDir = "/tmp/nexus-#{version}"
nexusDir = "#{node['liferay']['install_directory']}/liferay/webapps/nexus"
nexusHome = node['nexus']['home']
nexusHomeEscaped = nexusHome.dup.gsub!('/', '\\/')
nexusCfg = "#{nexusHome}/conf/nexus.xml"
hostname = node['nexus']['hostname']
ldapHost = node['ldap']['hostname']
ldapPort = node['ldap']['port']
ldapSuffix = ldapSuffix(node['ldap']['domain'])
ldapUser = node['nexus']['ldap']['user']
ldapUserDN = "cn=#{ldapUser},ou=Special Users,#{ldapSuffix}"
ldapPassword = node['nexus']['ldap']['password']
ldapPasswordHashed = ldapPassword(ldapPassword)
ldapDomainDN = "ou=#{hostname},ou=Domains,#{ldapSuffix}"
systemMailPrefix = node['nexus']['system_mail_prefix']
adminCN = node['ldap']['admin_cn']
adminEmail = "#{adminCN}@#{node['ldap']['domain']}"
mailServerHost = node['mail_server']['hostname']
systemEmailAddress = "#{systemMailPrefix}@#{hostname}"
ldapModifyParams = "-x -h #{ldapHost} -p #{ldapPort} -D cn='#{node['ldap']['dirmanager']}' -w #{node['ldap']['dirmanager_password']}"

# --- Download & deploy Nexus OSS ---
remote_file nexusWarFile do
  source "http://www.sonatype.org/downloads/nexus-#{version}.war"
  action :create_if_missing
end

directory nexusHome do
  owner usr
  group usr
  mode 01755
end

directory "#{nexusHome}/conf" do
  owner usr
  group usr
  mode 01755
end

template nexusCfg do
  source "nexus.xml.erb"
  owner usr
  group usr
  mode 00600
  variables({
    :hostname => hostname,
    :mailServerHost => mailServerHost,
    :mailServerUser => ldapUser,
    :mailServerPassword => ldapPassword,
    :systemEmailAddress => systemEmailAddress
  })
  action :create_if_missing
end

execute "Configure baseUrl" do
  command <<-EOH
sed -i 's/<baseUrl>.*?<\\/baseUrl>/<baseUrl>https:\\/\\/#{hostname}\\/nexus<\\/baseUrl>/g' #{nexusCfg} &&
sed -i 's/<forceBaseUrl>.*?<\\/forceBaseUrl>/<forceBaseUrl>true<\\/forceBaseUrl>/g' #{nexusCfg}
  EOH
end

template "#{nexusHome}/conf/security-configuration.xml" do
  source "nexus.security-configuration.xml.erb"
  owner usr
  group usr
  mode 00600
  action :create_if_missing
end

file "#{nexusHome}/conf/logback.properties" do
  owner usr
  group usr
  mode 00600
  content <<-EOH
root.level=ERROR
appender.pattern=%4d{yyyy-MM-dd HH\:mm\:ss} %-5p [%thread] %X{userId} %c - %m%n
appender.file=${nexus.log-config-dir}/../logs/nexus.log
  EOH
  action :create_if_missing
end

template "#{nexusHome}/conf/ldap.xml" do
  source "nexus.ldap.xml.erb"
  owner usr
  group usr
  mode 00600
  variables({
    :host => ldapHost,
    :port => ldapPort,
    :suffix => ldapSuffix,
    :user => ldapUser,
    :password => ldapPassword
  })
end

execute "Extract Sonatype Nexus" do
  cwd downloadDir
  command "mkdir #{nexusExtractDir} && unzip -qd /tmp/nexus-#{version} #{nexusWarFile}"
  not_if {File.exist?(nexusDir) || File.exist?(nexusExtractDir)}
end

execute "Configure home directory" do
  command "sed -i 's/^\\s*nexus-work\\s*=.*/nexus-work=#{nexusHomeEscaped}/' #{nexusExtractDir}/WEB-INF/plexus.properties"
  not_if {File.exist?(nexusDir)}
end

execute "Deploy Sonatype Nexus" do
  user usr
  group usr
  command <<-EOH
cp -r #{nexusExtractDir} #{nexusDir}
  EOH
  not_if {File.exist?(nexusDir)}
end

# --- Register Nexus LDAP user ---
execute "Register Nexus LDAP account" do
  command <<-EOH
echo "dn: #{ldapUserDN}
objectClass: javaContainer
objectClass: simpleSecurityObject
objectClass: top
objectClass: mailRecipient
cn: #{ldapUser}
mail: #{systemEmailAddress}
mailForwardingAddress: #{adminEmail}
userPassword:: #{ldapPasswordHashed}
" | ldapmodify #{ldapModifyParams} -a
  EOH
  not_if "ldapsearch #{ldapModifyParams} -b '#{ldapUserDN}'"
end

# --- Register Nexus hostname in LDAP ---
execute "Register Nexus hostname in LDAP" do
  command <<-EOH
echo "dn: #{ldapDomainDN}
objectClass: top
objectClass: organizationalUnit
objectClass: domainRelatedObject
ou: #{hostname}
associatedDomain: #{hostname}
" | ldapmodify #{ldapModifyParams} -a
  EOH
  not_if "ldapsearch #{ldapModifyParams} -b '#{ldapDomainDN}'"
end

# --- Register Nexus roles as LDAP groups ---
['nx-admin', 'nx-deployment'].each do |role|
  execute "Register Nexus role '#{role}' in LDAP" do
    command <<-EOH
echo "dn: cn=#{role},ou=groups,#{ldapSuffix}
objectClass: top
objectClass: groupOfUniqueNames
cn: #{role}
ou: groups
uniqueMember: cn=#{adminCN},ou=people,#{ldapSuffix}
" | ldapmodify #{ldapModifyParams} -a
    EOH
    not_if "ldapsearch #{ldapModifyParams} -b 'cn=#{role},ou=groups,#{ldapSuffix}'"
  end
end

# --- Configure nginx ---
template "/etc/nginx/sites-available/#{hostname}" do
  source "nexus.nginx.vhost.erb"
  mode 00700
  variables({
    :hostname => hostname,
    :port => node['liferay']['https_port']
  })
end

link "/etc/nginx/sites-enabled/#{hostname}" do
  to "/etc/nginx/sites-available/#{hostname}"
end

# --- Restart nginx ---
service "nginx" do
  action :restart
end
