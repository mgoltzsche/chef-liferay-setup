package 'openjdk-6-jdk'
package 'libssl-dev'
package 'imagemagick'
package 'unzip'

downloadDir = '/Downloads'
installDir = node['liferay-jetty']['install_directory']
mailServerHost = node['liferay-jetty']['mail_server_hostname'] || node['mail_server']['hostname']
adminScreenName = node['liferay-jetty']['admin']['screen_name'] || node['ldap']['instances']['default']['admin_cn'] || 'admin'
adminFullName = node['liferay-jetty']['admin']['full_name'] || "#{node['ldap']['instances']['default']['admin_givenName']} #{node['ldap']['instances']['default']['admin_sn']}"
adminEmail = node['liferay-jetty']['admin']['email'] || "#{node['ldap']['instances']['default']['admin_cn']}@#{node['ldap']['instances']['default']['domain']}"
adminPassword = node['liferay-jetty']['admin']['password'] || node['ldap']['instances']['default']['admin_password']
timezone = node['liferay-jetty']['timezone']
country = node['liferay-jetty']['country']
language = node['liferay-jetty']['language']

node['liferay-jetty']['instances'].each do |name, instance|
	instanceId = "liferay_#{name}"
	javaServer = instance['java_server'] || 'jetty'
	rootWebappName = javaServer == 'jetty' ? 'root' : 'ROOT'
	liferayDownloadUrl = instance['download_url'] || node['liferay-jetty']['instances']['default']['download_url']
	liferayZipFile = File.basename(URI.parse(liferayDownloadUrl).path)
	liferayFullName = liferayZipFile.gsub(/liferay-portal-[\w]+-(([\d]+\.?)+-[\w]+(-[\w]+)?)-[\d]+.zip/, 'liferay-portal-\1')
	extractionDir = "/tmp/#{javaServer}-installation/#{liferayFullName}"
	usr = instance['user'] || instanceId
	liferayDir = "#{installDir}/#{instanceId}"
	liferayRootWebappDir = "#{liferayDir}/webapps/#{rootWebappName}"
	homeDir = instance['home'] || "/var/opt/#{instanceId}"
	deployDir = "#{homeDir}/deploy"
	hostname = instance['hostname']
	companyName = instance['company_name'] || hostname
	nginxVhostFileName = name == 'default' ? 'default' : hostname
	systemMailPrefix = instance['system_mail_prefix'] || 'system'
    systemEmail = "#{systemMailPrefix}@#{hostname}"
	adminPassword = instance['admin_password'] || node['ldap']['instances']['default']['admin_password'] || 'password'
	pgPort = instance['pg']['port'] || 5432
	pgDB = instance['pg']['database'] || instanceId
	pgUser = instance['pg']['user'] || usr
	pgPassword = instance['pg']['password']
	ldapHost = instance['ldap']['hostname'] || node['ldap']['hostname']
	ldapPort = instance['ldap']['port'] || node['ldap']['instances'][name]['port'] || node['ldap']['instances']['default']['port']
	ldapSuffix = ldapSuffix(instance['ldap']['domain'] || node['ldap']['instances'][name]['domain'] || node['ldap']['instances']['default']['domain'])
	ldapUser = instance['ldap']['user'] || usr
	ldapUserDN="cn=#{ldapUser},ou=Special Users,#{ldapSuffix}"
	ldapPassword = instance['ldap']['password']
	ldapPasswordHashed = ldapPassword(ldapPassword)
	ldapModifyParams = "-x -h #{ldapHost} -p #{ldapPort} -D cn='#{node['ldap']['dirmanager']}' -w '#{node['ldap']['dirmanager_password']}'"
	defaultThemeId = 'classic'

	# --- Create Liferay system user ---
	user usr do
		comment 'Liferay User'
		shell '/bin/bash'
		home homeDir
		supports :manage_home => true
	end

	directory homeDir do
		owner usr
		group usr
		mode 0750
	end
	
	directory deployDir do
		owner usr
		group usr
		mode 00755
	end
	
	# --- Write configuration ---
	template "#{homeDir}/portal-ext.properties" do
		owner 'root'
		group usr
		source 'liferay.portal-ext.properties.erb'
		mode 0640
		variables({
			:defaultThemeId => defaultThemeId,
			:timezone => timezone,
			:country => country,
			:language => language,
			:company_name => companyName,
			:hostname => hostname,
			:admin_full_name => adminFullName,
			:admin_screen_name => adminScreenName,
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
#		notifies :restart, 'service[liferay]'
	end
	
	# --- Download & install Liferay ---
	directory downloadDir do
		mode 0755
	end

	remote_file "#{downloadDir}/#{liferayZipFile}" do
		source liferayDownloadUrl
		action :create_if_missing
	end
	
	execute 'Extract Liferay' do
		cwd downloadDir
		command <<-EOH
mkdir -p '/tmp/#{javaServer}-installation' &&
unzip -qd '/tmp/#{javaServer}-installation' '#{liferayZipFile}' &&
TMP_SERVER_DIR='#{extractionDir}/'$(ls '#{extractionDir}' | grep '#{javaServer}-') &&
cd "$TMP_SERVER_DIR/bin" &&
ls | grep '\\.bat$' | xargs rm &&
cd "$TMP_SERVER_DIR/webapps" &&
rm -rf welcome-theme sync-web opensocial-portlet notifications-portlet kaleo-web web-form-portlet &&
mkdir -p #{rootWebappName}/WEB-INF/classes/de/algorythm
STATUS=$?
if [ $STATUS -ne 0 ]; then
  rm -rf '#{extractionDir}'
fi
exit $STATUS
		EOH
		not_if {File.exist?(extractionDir)}
	end
	
	execute "Copy Liferay #{name} instance to installation directory" do
		command <<-EOH
TMP_SERVER_DIR='#{extractionDir}/'$(ls '#{extractionDir}' | grep '#{javaServer}-')
cp -R "$TMP_SERVER_DIR" '#{liferayDir}' &&
chown -R #{usr}:#{usr} '#{liferayDir}'
		EOH
		not_if {File.exist?(liferayDir)}
	end
	
	# --- Set logos & add contact form portlet ---
	cookbook_file "#{liferayRootWebappDir}/WEB-INF/classes/de/algorythm/logo.png" do
		owner usr
		group usr
		backup false
		action :create_if_missing
	end

	cookbook_file "#{liferayRootWebappDir}/favicon.ico" do
		owner usr
		group usr
		backup false
	end

	cookbook_file "#{liferayRootWebappDir}/html/themes/control_panel/images/favicon.ico" do
		owner usr
		group usr
		backup false
	end

	cookbook_file "#{deployDir}/contact-form.war" do
		owner usr
		group usr
		backup false
		not_if {File.exist?("#{liferayDir}/webapps/contact-form")}
	end
	
	# --- Create postgres user & DB ---
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

	# --- Register LDAP system account ---
	if ldapHost
		execute "Register Liferay LDAP account #{ldapUser}" do
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
	end

	# --- Register Liferay as service ---
#	template "/etc/init.d/#{instanceId}" do
#		source 'init.d.liferay.erb'
#		mode 0755
#		variables({
#			:name => name,
#			:liferayDir => liferayDir,
#			:user => usr
#		})
#	end

    # --- Configure nginx vhost ---
	template "/etc/nginx/sites-available/#{nginxVhostFileName}" do
		source 'liferay.nginx.vhost.erb'
		mode 0744
		variables({
			:hostname => hostname,
			:http_port => node['liferay']['http_port'],
			:https_port => node['liferay']['https_port']
		})
		notifies :restart, 'service[nginx]'
	end

	link "/etc/nginx/sites-enabled/#{nginxVhostFileName}" do
		to "/etc/nginx/sites-available/#{nginxVhostFileName}"
		notifies :restart, 'service[nginx]'
	end
	
	# --- (Re)start Liferay ---
#	service instanceId do
#		supports :restart => true
#		action :enable
#	end
end

# --- Restart nginx ---
service 'nginx' do
	supports :restart => true
	action :nothing
end
