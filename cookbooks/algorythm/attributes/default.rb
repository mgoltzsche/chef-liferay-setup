# Hostname
default['liferay']['hostname'] = 'dev.algorythm.de'

# Executing system user
default['liferay']['user'] = "liferay"

# DB: Postgres
default['liferay']['postgresql']['version'] = "9.1"
default['liferay']['postgresql']['dir'] = "/etc/postgresql/#{default['liferay']['postgresql']['version']}/main"
default['liferay']['postgresql']['port'] = 5432
default['liferay']['postgresql']['database'] = "liferay"
default['liferay']['postgresql']['user'] = "liferay_user"
default['liferay']['postgresql']['password'] = "liferay"

# Liferay installation
default['liferay']['download_url'] = "http://downloads.sourceforge.net/project/lportal/Liferay%20Portal/6.2.0%20GA1/liferay-portal-tomcat-6.2.0-ce-ga1-20131101192857659.zip?r=&ts=1383419991&use_mirror=garr"
default['liferay']['native_connectors_download_url'] = "http://apache.lehtivihrea.org//tomcat/tomcat-connectors/native/1.1.29/source/tomcat-native-1.1.29-src.tar.gz"
default['liferay']['apr_download_url'] = "http://mirror.synyx.de/apache/apr/apr-1.4.8.tar.bz2"
default['liferay']['install_directory'] = "/opt"
default['liferay']['java_opts'] = "-server -Xms128m -Xmx1024m -XX:MaxPermSize=512m"
default['liferay']['port'] = 8087

# Portal configuration
default['liferay']['company_default_name'] = "algorythm"
default['liferay']['admin']['name'] = "Max Goltzsche"
default['liferay']['admin']['email'] = "max.goltzsche@gmail.com"

# Sonatype Nexus
default['nexus']['version'] = "2.6.4"
default['nexus']['hostname'] = "nexus.dev.algorythm.de"

# Redmine installation
default['redmine']['install_directory'] = "/opt"
default['redmine']['version'] = "2.3.3"
default['redmine']['backlogs_version'] = "v1.0.6"
default['redmine']['user'] = "redmine"

# Redmine configuration
default['redmine']['hostname'] = "redmine.dev.algorythm.de"
default['redmine']['postgresql']['database'] = "redmine"
default['redmine']['postgresql']['user'] = "redmine"
default['redmine']['postgresql']['password'] = "redmine"
