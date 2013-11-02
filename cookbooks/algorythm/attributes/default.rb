# Hostname
default['liferay']['hostname'] = 'dev.algorythm.de'

# User
default['liferay']['user'] = "liferay"
default['liferay']['group'] = "liferay"

# Database: Postgres
default['liferay']['postgresql']['version'] = "9.1"
default['liferay']['postgresql']['dir'] = "/etc/postgresql/#{default['liferay']['postgresql']['version']}/main"
default['liferay']['postgresql']['port'] = 5432
default['liferay']['postgresql']['admin_password'] = "postgres"
default['liferay']['postgresql']['user'] = "liferay_user"
default['liferay']['postgresql']['user_password'] = "liferay"
default['liferay']['postgresql']['database']['default'] = "liferay"

# Liferay
default['liferay']['download_url'] = "http://downloads.sourceforge.net/project/lportal/Liferay%20Portal/6.2.0%20GA1/liferay-portal-tomcat-6.2.0-ce-ga1-20131101192857659.zip?r=&ts=1383419991&use_mirror=garr"
default['liferay']['install_directory'] = "/opt"

