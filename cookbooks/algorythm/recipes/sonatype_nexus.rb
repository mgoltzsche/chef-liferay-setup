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
ldapUser = node['ldap']['dirmanager']
ldapPassword = node['ldap']['dirmanager_password']
ldapSuffix = node['ldap']['domain'].split('.').map{|dc| "dc=#{dc}"}.join(',')
mailServerHost = node['mail_server']['hostname']
mailServerUser = node['ldap']['admin_cn']
mailServerPassword = node['ldap']['admin_password']

package 'zip'

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
    :mailServerUser => mailServerUser,
    :mailServerPassword => mailServerPassword
  })
  action :create_if_missing
end

template "#{nexusHome}/conf/security-configuration.xml" do
  source "nexus.security-configuration.xml.erb"
  owner usr
  group usr
  mode 00600
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

#execute "Configure nexus baseUrl" do
#  command <<-EOH
#sed -i 's/<baseUrl>.*?<\\/baseUrl>/<baseUrl>https:\\/\\/#{hostname}\\/nexus<\\/baseUrl>/g' #{nexusCfg} &&
#sed -i 's/<forceBaseUrl>.*?<\\/forceBaseUrl>/<forceBaseUrl>true<\\/forceBaseUrl>/g' #{nexusCfg}
#  EOH
#end

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
