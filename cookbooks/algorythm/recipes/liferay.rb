require 'uri'

usr = node['liferay']['user']
downloadDir = "/Downloads"
liferayZipFile = File.basename(URI.parse(node['liferay']['download_url']).path)
liferayFullName = liferayZipFile.gsub(/liferay-portal-[\w]+-(([\d]+\.?)+-[\w]+(-[\w]+)?)-[\d]+.zip/, 'liferay-portal-\1')
liferayExtractionDir = "/tmp/#{liferayFullName}"
aprSourceArchive = File.basename(URI.parse(node['liferay']['apr_download_url']).path)
aprSourceFolder = aprSourceArchive.gsub(/(.*?)\.tar\.bz2/, '\1')
aprSourcePath = "#{downloadDir}/#{aprSourceFolder}"
nativeConnectorSourceArchive = File.basename(URI.parse(node['liferay']['native_connectors_download_url']).path)
nativeConnectorSourceFolder = nativeConnectorSourceArchive.gsub(/(.*?)\.tar\.gz/, '\1')
nativeConnectorSourcePath = "#{downloadDir}/#{nativeConnectorSourceFolder}"
liferayDir = "#{node['liferay']['install_directory']}/#{liferayFullName}"
liferayDirLink = "#{node['liferay']['install_directory']}/liferay"
liferayHomeDir = node['liferay']['home_directory']
tomcatVirtualHosts = node['liferay']['tomcat_virtual_hosts']
liferayInstances = node['liferay']['instances']
ldapHost = node['ldap']['hostname']
ldapPort = node['ldap']['instances']['default']['port']
ldapSuffix = ldapSuffix(node['ldap']['instances']['default']['domain'])
ldapUser = node['liferay']['ldap']['user']
ldapUserDN = "cn=#{ldapUser},ou=Special Users,#{ldapSuffix}"
ldapPassword = node['liferay']['ldap']['password']
ldapPasswordHashed = ldapPassword(ldapPassword)
systemMailPrefix = node['liferay']['system_mail_prefix']
systemEmail = "#{systemMailPrefix}@#{node['liferay']['instances']['default']['hostname']}"
mailServerHost = node['mail_server']['hostname']
admin = node['ldap']['instances']['default']['admin_cn']
adminPassword = node['ldap']['instances']['default']['admin_password']
adminEmail = "#{admin}@#{node['ldap']['instances']['default']['domain']}"
timezone = node['liferay']['timezone']
country = node['liferay']['country']
language = node['liferay']['language']
ldapModifyParams = "-x -h #{ldapHost} -p #{ldapPort} -D cn='#{node['ldap']['dirmanager']}' -w '#{node['ldap']['dirmanager_password']}'"

package 'openjdk-6-jdk'
package 'libssl-dev'
package 'imagemagick'
package 'unzip'

# --- Create Liferay system user ---
user usr do
  comment 'Liferay User'
  shell '/bin/bash'
  home "#{liferayHomeDir}/#{usr}"
  supports :manage_home => true
end

# --- Create Liferay LDAP user ---
execute "Register Liferay LDAP account" do
  command <<-EOH
echo "dn: #{ldapUserDN}
objectClass: javaContainer
objectClass: simpleSecurityObject
objectClass: top
objectClass: mailRecipient
cn: #{ldapUser}
mail: #{systemEmail}
mailForwardingAddress: #{adminEmail}
userPassword:: #{ldapPasswordHashed}
" | ldapmodify #{ldapModifyParams} -a
  EOH
  not_if "ldapsearch #{ldapModifyParams} -b '#{ldapUserDN}'"
end

execute "Grant Directory Administrator privileges to Liferay LDAP account" do
  command <<-EOH
echo "dn: cn=Directory Administrators,#{ldapSuffix}
changetype: modify
add: uniqueMember
uniqueMember: #{ldapUserDN}
" | ldapmodify #{ldapModifyParams}
  EOH
  not_if "ldapsearch #{ldapModifyParams} -b 'cn=Directory Administrators,#{ldapSuffix}' '(uniqueMember=#{ldapUserDN})' | grep -P '^# numEntries: [\\d]+$'"
end

# --- Download and install Liferay ---
directory downloadDir do
  mode 0755
end

remote_file "#{downloadDir}/#{liferayZipFile}" do
  source node['liferay']['download_url']
  action :create_if_missing
end

execute 'Extract Liferay' do
  cwd downloadDir
  command <<-EOH
unzip -qd /tmp #{liferayZipFile} &&
TMP_TOMCAT_DIR='#{liferayExtractionDir}/'$(ls '#{liferayExtractionDir}' | grep tomcat) &&
cd "$TMP_TOMCAT_DIR/bin" &&
ls | grep '\\.bat$' | xargs rm &&
cd "$TMP_TOMCAT_DIR/webapps" &&
rm -rf welcome-theme sync-web opensocial-portlet notifications-portlet kaleo-web web-form-portlet &&
mkdir -p ROOT/WEB-INF/classes/de/algorythm
  EOH
  not_if {File.exist?(liferayExtractionDir)}
end

execute 'Copy Liferay to installation directory' do
  command <<-EOH
TMP_TOMCAT_DIR='#{liferayExtractionDir}/'$(ls '#{liferayExtractionDir}' | grep tomcat)
cp -R "$TMP_TOMCAT_DIR" #{liferayDir} &&
chown -R #{usr}:#{usr} #{liferayDir}
  EOH
  not_if {File.exist?(liferayDir)}
end

link liferayDirLink do
  to liferayDir
end

# --- Create Liferay instance webapps dir, home dir, configuration, nginx vhost, postgres user and database
liferayInstances.each do |name, instance|
  nginxVhostFileName = name == 'default' ? 'default' : instance['hostname']
  webappsDir = name == 'default' ? "#{liferayDir}/webapps" : "#{liferayDir}/webapps-#{name}"
  homeDir = "#{liferayHomeDir}/liferay-#{name}"
  pgPort = instance['pg']['port']
  pgDB = instance['pg']['database']
  pgUser = instance['pg']['user'] ? instance['pg']['user'] : pgDB
  pgPassword = instance['pg']['password']
  defaultThemeWar = instance['default_theme_war']
  defaultThemeId = ''

  directory "#{liferayDir}/webapps-#{name}" do
    owner usr
    group usr
    mode 0750
  end

  if (name != 'default')
    execute "Copy Liferay webapp to webapps-#{name}" do
      command <<-EOH
VANILLA_LIFERAY_WEBAPP='#{liferayExtractionDir}/'$(ls '#{liferayExtractionDir}' | grep tomcat)/webapps/ROOT
cp -R "$VANILLA_LIFERAY_WEBAPP" '#{webappsDir}/ROOT' &&
mkdir -p '#{webappsDir}/ROOT/WEB-INF/classes/de/algorythm' &&
chown -R #{usr}:#{usr} '#{webappsDir}/ROOT'
      EOH
      not_if {File.exist?("#{webappsDir}/ROOT")}
    end
  end

  directory homeDir do
    owner usr
    group usr
    mode 0750
  end

  directory "#{homeDir}/deploy" do
    owner usr
    group usr
    mode 00755
  end

  if defaultThemeWar
    warName = File.basename(URI.parse(defaultThemeWar).path).gsub!(/(.*).war$/, '\1')
    defaultThemeIdPart = warName.gsub!(/-_ /, '')
    defaultThemeId = "#{defaultThemeIdPart}_WAR_#{defaultThemeIdPart}"
    execute "Deploy default theme for #{name} instance" do
      user usr
      group usr
      command "cp '#{defaultThemeWar}' '#{homeDir}/deploy'"
      not_if {File.exist?("#{webappsDir}/#{warName}")}
    end    
  end

  execute "Create liferay postgres user '#{pgUser}'" do
    user 'postgres'
    command "psql -U postgres -c \"CREATE USER #{pgUser};\""
    not_if("psql -U postgres -c \"SELECT * FROM pg_user WHERE usename='#{pgUser}';\" | grep #{pgUser}", :user => 'postgres')
  end

  execute "Set postgres user password of '#{pgUser}'" do
    user 'postgres'
    command "psql -U postgres -c \"ALTER ROLE #{pgUser} ENCRYPTED PASSWORD '#{pgPassword}';\""
  end

  execute "Create database '#{pgDB}'" do
    user 'postgres'
    command "createdb '#{pgDB}' -O #{pgUser} -E UTF8 -T template0"
    not_if("psql -c \"SELECT datname FROM pg_catalog.pg_database WHERE datname='#{pgDB}';\" | grep '#{pgDB}'", :user => 'postgres')
  end

  cookbook_file "#{webappsDir}/ROOT/WEB-INF/classes/de/algorythm/logo.png" do
    owner usr
    group usr
    backup false
    action :create_if_missing
  end

  cookbook_file "#{webappsDir}/ROOT/favicon.ico" do
    owner usr
    group usr
    backup false
  end

  cookbook_file "#{webappsDir}/ROOT/html/themes/control_panel/images/favicon.ico" do
    owner usr
    group usr
    backup false
  end

  cookbook_file "#{homeDir}/deploy/contact-form.war" do
    owner usr
    group usr
    backup false
    not_if {File.exist?("#{webappsDir}/contact-form")}
  end

  template "#{webappsDir}/ROOT/portal-ext.properties" do
    owner 'root'
    group usr
    source 'liferay.portal-ext.properties.erb'
    mode 0640
    variables({
      :liferayHome => homeDir,
      :defaultThemeId => defaultThemeId,
      :timezone => timezone,
      :country => country,
      :language => language,
      :company_name => instance['company_default_name'],
      :hostname => instance['hostname'],
      :admin_full_name => node['liferay']['admin']['name'],
      :admin_screen_name => admin,
      :admin_email => adminEmail,
      :admin_password => adminPassword,
      :system_email => systemEmail,
      :mailServerHost => mailServerHost,
      :pgPort => pgPort,
      :pgDB => pgDB,
      :pgUser => pgUser,
      :pgPassword => pgPassword,
      :ldapHost => ldapHost,
      :ldapPort => ldapPort,
      :ldapSuffix => ldapSuffix,
      :ldapUser => ldapUser,
      :ldapPassword => ldapPassword
    })
    notifies :restart, 'service[liferay]'
  end

  template "/etc/nginx/sites-available/#{nginxVhostFileName}" do
    source 'liferay.nginx.vhost.erb'
    mode 0744
    variables({
      :hostname => instance['hostname'],
      :http_port => node['liferay']['http_port'],
      :https_port => node['liferay']['https_port']
    })
    notifies :restart, 'service[nginx]'
  end

  link "/etc/nginx/sites-enabled/#{nginxVhostFileName}" do
    to "/etc/nginx/sites-available/#{nginxVhostFileName}"
    notifies :restart, 'service[nginx]'
  end
end

# --- Download & install native APR library ---
remote_file "#{downloadDir}/#{aprSourceArchive}" do
  source node['liferay']['apr_download_url']
  action :create_if_missing
end

remote_file "#{downloadDir}/#{nativeConnectorSourceArchive}" do
  source node['liferay']['native_connectors_download_url']
  action :create_if_missing
end

execute 'Extract APR source' do
  cwd downloadDir
  user 'root'
  group 'root'
  command "tar xvjf #{downloadDir}/#{aprSourceArchive}"
  not_if {File.exist?(aprSourcePath)}
end

execute "Extract native connectors source" do
  cwd downloadDir
  user 'root'
  group 'root'
  command "tar xvzf #{downloadDir}/#{nativeConnectorSourceArchive}"
  not_if {File.exist?(nativeConnectorSourcePath)}
end

execute 'Compile APR source' do
  cwd aprSourcePath
  user 'root'
  group 'root'
  command <<-EOH
./configure &&
make &&
make install
  EOH
  not_if 'ls /usr/local/apr/lib | grep libapr-'
end

execute 'Compile native connectors source' do
  cwd "#{nativeConnectorSourcePath}/jni/native"
  user 'root'
  group 'root'
  command <<-EOH
./configure --with-apr=/usr/local/apr --with-java-home=/usr/lib/jvm/java-6-openjdk-amd64 &&
make &&
make install
  EOH
  not_if 'ls /usr/local/apr/lib | grep libtcnative-'
end

# --- Configure Liferay tomcat ---
tomcatVirtualHosts.keys.each do |vhost|
  directory "#{liferayDir}/webapps-#{vhost}" do
    owner usr
    group usr
    mode 0750
  end
end

template "#{liferayDir}/bin/setenv.sh" do
  owner 'root'
  group usr
  source 'liferay.tomcat.setenv.sh.erb'
  mode 0754
  variables({
    :catalina_opts => node['liferay']['catalina_opts']
  })
  notifies :restart, 'service[liferay]'
end

template "#{liferayDir}/conf/server.xml" do
  owner 'root'
  group usr
  source 'liferay.tomcat.server.xml.erb'
  mode 0644
  variables({
    :httpPort => node['liferay']['http_port'],
    :httpsPort => node['liferay']['https_port'],
    :liferayInstances => liferayInstances,
    :virtualHosts => tomcatVirtualHosts
  })
  notifies :restart, 'service[liferay]'
end

# --- Register Liferay as service ---
template '/etc/init.d/liferay' do
  source 'init.d.liferay.erb'
  mode 0755
  variables({
    :liferayDir => liferayDirLink,
    :user => usr
  })
end

template '/etc/logrotate.d/liferay' do
  source 'logrotate.d.liferay.erb'
  mode 0755
  variables({
    :liferay_log_home => "#{liferayDirLink}/logs"
  })
end

# --- Configure backup ---
template "#{node['backup']['install_directory']}/tasks/liferay" do
  source 'backup.liferay.erb'
  owner 'root'
  group 'root'
  mode 0744
  variables({
    :home => liferayHomeDir,
    :user => usr
  })
end

# --- Restart nginx ---
service 'nginx' do
  supports :restart => true
  action :nothing
end

# --- (Re)start Liferay ---
service 'liferay' do
  supports :restart => true
  action :enable
end

print <<-EOH
###############################################################################
# Please login to Liferay as administrator after the installation,            #
# go to the LDAP configuration dialog and test your connection                #
# (and enable export manually).                                               #
# Afterwards LDAP users can login (and user data is exported).                #
###############################################################################
EOH
