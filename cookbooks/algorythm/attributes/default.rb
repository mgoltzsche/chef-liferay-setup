# Hostname
default['hostname'] = 'dev-master'
default['domainname'] = 'dev.algorythm.de'
default['max_open_files'] = 100000 # Should be > 1024
default['tcp_timeout'] = 600 # Should be lower to free worker threads earlier

# backup
default['backup'] = {
	'install_directory' => '/opt/backup-scripts',
	'backup_directory' => '/var/backups/managed'
}

# LDAP configuration
default['ldap']['dirmanager'] = 'dirmanager'
default['ldap']['dirmanager_password'] = 'password'
default['ldap']['hostname'] = 'localhost'
default['ldap']['instances']['default'] = {
	'listenhost' => '127.0.0.1',
	'port' => 389,
	'domain' => 'dev.algorythm.de',
	'admin_cn' => 'admin',
	'admin_sn' => 'Goltzsche',
	'admin_givenName' => 'Max',
	'admin_password' => 'password'
}

# Mail Server configuration
default['mail_server'] = {
	'hostname' => 'localhost',
	'vmail_user' => 'vmail',
	'vmail_directory' => '/var/vmail',
	'ldap' => {
		'user' => 'vmail',
		'password' => 'password'
	}
}

# Postgresql installation
default['postgresql'] = {
	'address' => 'localhost',
	'port' => 5432,
	'version' => '9.1'
}

# Liferay installation
default['liferay-jetty']['install_directory'] = '/opt'
default['liferay-jetty']['timezone'] = 'Europe/Berlin'
default['liferay-jetty']['country'] = 'DE'
default['liferay-jetty']['language'] = 'de'
default['liferay-jetty']['mail_server_hostname'] = nil
default['liferay-jetty']['admin'] = {
	'screen_name' => nil,
	'full_name' => nil,
	'email' => nil,
	'password' => 'password'
}
default['liferay-jetty']['instances']['default'] = {
	'download_url' => 'http://downloads.sourceforge.net/project/lportal/Liferay%20Portal/6.2.0%20GA1/liferay-portal-jetty-6.2.0-ce-ga1-20131101192857659.zip?r=&ts=1388349536&use_mirror=garr',
	'java_server' => 'jetty',
	'hostname' => default['ldap']['instances']['default']['domain'],
	'port' => 7080,
	'company_name' => nil,
	'system_mail_prefix' => 'system',
	'user' => nil,
	'default_theme_war' => nil,
	'pg' => {
		'port' => 5432,
		'database' => nil,
		'password' => 'password'
	},
	'ldap' => {
		'hostname' => nil,
		'port' => nil,
		'user' => nil,
		'password' => 'password'
	}
}
default['liferay'] = {
	'download_url' => 'http://downloads.sourceforge.net/project/lportal/Liferay%20Portal/6.2.0%20GA1/liferay-portal-tomcat-6.2.0-ce-ga1-20131101192857659.zip?r=&ts=1383419991&use_mirror=garr',
	'native_connectors_download_url' => 'ftp://ftp.fu-berlin.de/unix/www/apache/tomcat/tomcat-connectors/native/1.1.29/source/tomcat-native-1.1.29-src.tar.gz',
	'apr_download_url' => 'ftp://ftp.fu-berlin.de/unix/www/apache/apr/apr-1.5.0.tar.bz2',
	'install_directory' => '/opt',
	'home' => '/var/opt/liferay',
	'user' => 'liferay',
	'catalina_opts' => '-server -Xms128m -Xmx1024m -XX:MaxPermSize=512m',
	'http_port' => 7080,
	'https_port' => 7443,

	'system_mail_prefix' => 'system',
	'admin' => {'name' => 'Max Goltzsche'},
	'timezone' => 'Europe/Berlin',
	'country' => 'DE',
	'language' => 'de',
	'tomcat_virtual_hosts' => {
		'nexus' => "repository.#{default['ldap']['instances']['default']['domain']}"
	},
	'instances' => {
		'default' => {
			'hostname' => default['ldap']['instances']['default']['domain'],
			'company_default_name' => default['ldap']['instances']['default']['domain'],
			'system_mail_prefix' => 'system',
            'admin_password' => nil,
			'pg' => {
				'port' => 5432,
				'database' => 'liferay',
				'password' => 'password'
			},
			'ldap' => {
				'user' => 'liferay',
				'password' => 'password'
			}
		}
	}
}

# Sonatype Nexus installation
default['nexus'] = {
	'version' => '2.7.0-06',
	'hostname' => "repository.#{default['ldap']['instances']['default']['domain']}",
	'system_mail_prefix' => 'system',
	'deploy_directory' => "#{default['liferay']['install_directory']}/liferay/webapps-nexus",
	'home' => '/var/opt/nexus',
	'ldap' => {
		'user' => 'nexus',
		'password' => 'password'
	}
}

# Redmine Backlogs installation
default['redmine'] = {
	'install_directory' => '/opt',
	'home' => '/var/opt/redmine',
	'user' => 'redmine',
	'version' => '2.3.3',
	'backlogs_version' => 'v1.0.6',

	'hostname' => "redmine.#{default['ldap']['instances']['default']['domain']}",
	'system_mail_prefix' => 'system',
	'postgresql' => {
		'database' => 'redmine',
		'user' => 'redmine',
		'password' => 'password'
	},
	'ldap' => {
		'user' => 'redmine',
		'password' => 'password'
	}
}
