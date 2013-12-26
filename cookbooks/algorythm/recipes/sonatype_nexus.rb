usr = node['liferay']['user']
downloadDir = "/Downloads"
version = node['nexus']['version']
nexusWarFile = "#{downloadDir}/nexus-#{version}.war"
nexusExtractDir = "/tmp/nexus-#{version}"
nexusDir = "#{node['nexus']['deploy_directory']}/ROOT"
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
anonymousEmailAddress = "anonymous@#{hostname}"
ldapModifyParams = "-x -h #{ldapHost} -p #{ldapPort} -D cn='#{node['ldap']['dirmanager']}' -w #{node['ldap']['dirmanager_password']}"

# --- Download & deploy Nexus OSS ---
remote_file nexusWarFile do
  source "http://www.sonatype.org/downloads/nexus-#{version}.war"
  action :create_if_missing
end

directory nexusHome do
  owner usr
  group usr
  mode 0755
end

directory "#{nexusHome}/conf" do
  owner usr
  group usr
  mode 0755
end

template nexusCfg do
  source "nexus.xml.erb"
  owner usr
  group usr
  mode 0600
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
  command "sed -i 's/<baseUrl>.*?<\\/baseUrl>/<baseUrl>https:\\/\\/#{hostname}\\/nexus<\\/baseUrl>/g' #{nexusCfg}"
  not_if "cat #{nexusCfg} | grep '<baseUrl>https://#{hostname}/nexus</baseUrl>'"
end

template "#{nexusHome}/conf/security-configuration.xml" do
  source "nexus.security-configuration.xml.erb"
  owner usr
  group usr
  mode 0600
  action :create_if_missing
end

template "#{nexusHome}/conf/security.xml" do
  source "nexus.security.xml.erb"
  owner usr
  group usr
  mode 0600
  variables({
    :anonymousEmailAddress => anonymousEmailAddress
  })
  action :create_if_missing
end

file "#{nexusHome}/conf/logback.properties" do
  owner usr
  group usr
  mode 0600
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
  mode 0600
  variables({
    :host => ldapHost,
    :port => ldapPort,
    :suffix => ldapSuffix,
    :user => ldapUser,
    :password => ldapPassword
  })
  notifies :restart, 'service[liferay]'
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

['nexus-outreach-plugin', 'nexus-yum-repository-plugin', 'nexus-atlas-plugin', 'nexus-lvo-plugin', 'nexus-wonderland-plugin'].each do |plugin|
  execute "Remove superfluous #{plugin}" do
    cwd "#{nexusExtractDir}/WEB-INF/plugin-repository"
    command "rm -rf $(ls | grep #{plugin})"
    not_if {File.exist?(nexusDir)}
  end
end

execute "Deploy Sonatype Nexus" do
  user usr
  group usr
  command <<-EOH
cp -r #{nexusExtractDir} #{nexusDir}
  EOH
  not_if {File.exist?(nexusDir)}
  notifies :restart, 'service[liferay]'
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
mailAlternateAddress: #{anonymousEmailAddress}
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
['nx-admin', 'developer-snapshots', 'developer-releases'].each do |role|
  execute "Register Nexus role '#{role}' in LDAP" do
    command <<-EOH
echo "dn: cn=#{role},ou=groups,#{ldapSuffix}
objectClass: top
objectClass: groupOfUniqueNames
cn: #{role}
ou: groups
description: Nexus role
uniqueMember: cn=#{adminCN},ou=people,#{ldapSuffix}
" | ldapmodify #{ldapModifyParams} -a
    EOH
    not_if "ldapsearch #{ldapModifyParams} -b 'cn=#{role},ou=groups,#{ldapSuffix}'"
  end
end

# --- Configure backup ---
template "#{node['backup']['install_directory']}/tasks/nexus" do
  source 'backup.nexus.erb'
  owner 'root'
  group 'root'
  mode 0700
  variables({
    :home => nexusHome,
    :user => usr
  })
end

# --- Configure nginx ---
template "/etc/nginx/sites-available/#{hostname}" do
  source 'nexus.nginx.vhost.erb'
  mode 00700
  variables({
    :hostname => hostname,
    :port => node['liferay']['https_port']
  })
  notifies :restart, 'service[nginx]'
end

link "/etc/nginx/sites-enabled/#{hostname}" do
  to "/etc/nginx/sites-available/#{hostname}"
  notifies :restart, 'service[nginx]'
end

# --- Restart nginx ---
service 'nginx' do
  supports :restart => true
  action :nothing
end

# --- (Re)start Liferay ---
service 'liferay' do
  supports :restart => true
  action :nothing
end
