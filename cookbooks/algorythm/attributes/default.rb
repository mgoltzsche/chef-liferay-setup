# Hostname
default['liferay']['hostname'] = 'dev.algorythm.de'

# Executing system user
default['liferay']['user'] = "liferay"

# Postgresql
default['postgresql']['version'] = "9.1"
default['postgresql']['dir'] = "/etc/postgresql/#{default['liferay']['postgresql']['version']}/main"
default['postgresql']['port'] = 5432

# Liferay installation
default['liferay']['download_url'] = "http://downloads.sourceforge.net/project/lportal/Liferay%20Portal/6.2.0%20GA1/liferay-portal-tomcat-6.2.0-ce-ga1-20131101192857659.zip?r=&ts=1383419991&use_mirror=garr"
default['liferay']['native_connectors_download_url'] = "http://apache.lehtivihrea.org//tomcat/tomcat-connectors/native/1.1.29/source/tomcat-native-1.1.29-src.tar.gz"
default['liferay']['apr_download_url'] = "http://mirror.synyx.de/apache/apr/apr-1.4.8.tar.bz2"
default['liferay']['install_directory'] = "/opt"
default['liferay']['java_opts'] = "-server -Xms128m -Xmx1024m -XX:MaxPermSize=512m"
default['liferay']['http_port'] = 8087
default['liferay']['https_port'] = 8089

# Portal configuration
default['liferay']['company_default_name'] = "algorythm"
default['liferay']['admin']['name'] = "Max Goltzsche"
default['liferay']['admin']['email'] = "max.goltzsche@gmail.com"
default['liferay']['postgresql']['database'] = "liferay"
default['liferay']['postgresql']['user'] = default['liferay']['user']
default['liferay']['postgresql']['password'] = "liferay"

# Sonatype Nexus
default['nexus']['version'] = "2.6.4"
default['nexus']['hostname'] = "nexus.#{default['liferay']['hostname']}"

# Redmine installation
default['redmine']['install_directory'] = "/opt"
default['redmine']['version'] = "2.3.3"
default['redmine']['backlogs_version'] = "v1.0.6"
default['redmine']['user'] = "redmine"

# Redmine configuration
default['redmine']['hostname'] = "redmine.#{default['liferay']['hostname']}"
default['redmine']['postgresql']['database'] = "redmine"
default['redmine']['postgresql']['user'] = default['redmine']['user']
default['redmine']['postgresql']['password'] = "redmine"
