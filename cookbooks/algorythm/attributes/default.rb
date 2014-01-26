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
	'admin_password' => 'ldap123'
}

# Mail Server configuration
default['mail_server'] = {
	'hostname' => 'localhost',
	'vmail_user' => 'vmail',
	'vmail_directory' => '/var/vmail',
	'ldap' => {
		'user' => 'vmail',
		'password' => 'mail123'
	}
}

# Postgresql installation
default['postgresql'] = {
	'address' => 'localhost',
	'port' => 5432,
	'version' => '9.1'
}

# Liferay installation
default['liferay']['install_directory'] = '/opt'
default['liferay']['timezone'] = 'Europe/Berlin'
default['liferay']['country'] = 'DE'
default['liferay']['language'] = 'de'
default['liferay']['mail_server_hostname'] = nil
default['liferay']['admin'] = {
	'screen_name' => nil,
	'full_name' => nil,
	'email' => nil,
	'password' => 'admin123'
}
default['liferay']['instances']['default'] = {
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
		'password' => 'admin123'
	},
	'ldap' => {
		'hostname' => nil,
		'port' => nil,
		'user' => nil,
		'password' => 'admin123'
	}
}

# Sonatype Nexus installation
default['nexus'] = {
	'version' => '2.7.1-01',
	'hostname' => "repository.#{default['ldap']['instances']['default']['domain']}",
	'system_mail_prefix' => 'system',
	'install_directory' => "#{default['liferay']['install_directory']}/liferay_default/webapps",
	'jetty_vhost_directory' => "#{default['liferay']['install_directory']}/liferay_default/contexts",
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
