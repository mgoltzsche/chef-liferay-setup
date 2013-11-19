# Hostname
default['hostname'] = 'dev-master'
default['domainname'] = 'dev.algorythm.de'
default['max_open_files'] = 4096 # Should be > 1024
default['tcp_timeout'] = 600 # Should be lower to free worker threads earlier

# LDAP configuration
default['ldap']['listenhost'] = '0.0.0.0'
default['ldap']['hostname'] = 'localhost'
default['ldap']['port'] = 389
default['ldap']['dirmanager'] = 'dirmanager'
default['ldap']['dirmanager_password'] = 'password'
default['ldap']['domain'] = 'dev.algorythm.de'
default['ldap']['user_cn'] = 'admin'
default['ldap']['user_sn'] = 'Goltzsche'
default['ldap']['user_givenName'] = 'Max'

# Mail Server configuration
default['mail_server']['hostname'] = 'localhost'
default['mail_server']['vmail_user'] = 'vmail'
default['mail_server']['vmail_directory'] = '/var/vmail'

# Postgresql installation
default['postgresql']['address'] = "localhost"
default['postgresql']['port'] = 5432
default['postgresql']['version'] = "9.1"

# Liferay installation
default['liferay']['download_url'] = "http://downloads.sourceforge.net/project/lportal/Liferay%20Portal/6.2.0%20GA1/liferay-portal-tomcat-6.2.0-ce-ga1-20131101192857659.zip?r=&ts=1383419991&use_mirror=garr"
default['liferay']['native_connectors_download_url'] = "http://apache.lehtivihrea.org//tomcat/tomcat-connectors/native/1.1.29/source/tomcat-native-1.1.29-src.tar.gz"
default['liferay']['apr_download_url'] = "http://mirror.synyx.de/apache/apr/apr-1.4.8.tar.bz2"
default['liferay']['install_directory'] = "/opt"
default['liferay']['user'] = "liferay"
default['liferay']['java_opts'] = "-server -Xms128m -Xmx1024m -XX:MaxPermSize=512m"
default['liferay']['http_port'] = 8087
default['liferay']['https_port'] = 8089

# Liferay Portal configuration
default['liferay']['hostname'] = default['ldap']['domain']
default['liferay']['company_default_name'] = "algorythm"
default['liferay']['admin']['name'] = "Max Goltzsche"
default['liferay']['admin']['email'] = "admin@#{default['ldap']['domain']}"
default['liferay']['postgresql']['database'] = "liferay"
default['liferay']['postgresql']['user'] = default['liferay']['user']
default['liferay']['postgresql']['password'] = "liferay"

# Sonatype Nexus installation
default['nexus']['version'] = "2.6.4"
default['nexus']['hostname'] = "nexus.#{default['liferay']['hostname']}"

# Redmine Backlogs installation
default['redmine']['install_directory'] = "/opt"
default['redmine']['user'] = "redmine"
default['redmine']['version'] = "2.3.3"
default['redmine']['backlogs_version'] = "v1.0.6"

# Redmine Backlogs configuration
default['redmine']['hostname'] = "redmine.#{default['liferay']['hostname']}"
default['redmine']['postgresql']['database'] = "redmine"
default['redmine']['postgresql']['user'] = default['redmine']['user']
default['redmine']['postgresql']['password'] = "redmine"
