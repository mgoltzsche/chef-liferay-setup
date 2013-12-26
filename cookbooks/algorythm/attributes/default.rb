# Hostname
default['hostname'] = 'dev-master'
default['domainname'] = 'dev.algorythm.de'
default['max_open_files'] = 4096 # Should be > 1024
default['tcp_timeout'] = 600 # Should be lower to free worker threads earlier

# backup
default['backup'] = {
	'install_directory' => '/opt/backup-scripts',
	'backup_directory' => '/var/backups/managed'
}

# LDAP configuration
default['ldap'] = {
	'listenhost' => '127.0.0.1',
	'hostname' => 'localhost',
	'port' => 389,
	'dirmanager' => 'dirmanager',
	'dirmanager_password' => 'password',
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
		'user' => default['mail_server']['vmail_user'],
		'password' => 'password'
	}
}

# Postgresql installation
default['postgresql'] = {
	'address' => "localhost",
	'port' => 5432,
	'version' => '9.1'
}

# Liferay installation
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

	'company_default_name' => default['ldap']['domain'],
	'system_mail_prefix' => 'system',
	'admin' => {'name' => 'Max Goltzsche'},
	'timezone' => 'Europe/Berlin',
	'country' => 'DE',
	'language' => 'de',
	'tomcat_virtual_hosts' => {
		'nexus' => "repository.#{default['ldap']['domain']}"
	},
	'defaultshard' => 'default',
	'shards' => {
		'default' => {
			'hostname' => default['ldap']['domain'],
			'pg' => {
				'port' => 5432,
				'database' => 'liferay',
				'user' => 'liferay',
				'password' => 'password'
			}
		},
		'dieter-goltzsche' => {
			'hostname' => 'dieter-goltzsche.de',
			'pg' => {
				'port' => 5432,
				'database' => 'liferay_dieter_goltzsche',
				'user' => 'dieter_goltzsche',
				'password' => 'password'
			}
		}
	},
	'ldap' => {
		'user' => 'liferay',
		'password' => 'password'
	}
}

# Sonatype Nexus installation
default['nexus'] = {
	'version' => '2.7.0-06',
	'hostname' => "repository.#{default['domainname']}",
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

	'hostname' => "redmine.#{default['domainname']}",
	'system_mail_prefix' => 'system',
	'postgresql' => {
		'database' => 'redmine',
		'user' => 'redmine',
		'password' => 'password'
	},
	'ldap' => {
		'user' => default['redmine']['user'],
		'password' => 'password'
	}
}
