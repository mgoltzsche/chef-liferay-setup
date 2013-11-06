# Hostname
default['liferay']['hostname'] = 'dev.algorythm.de'

# Executing system user
default['liferay']['user'] = "liferay"

# DB: Postgres
default['liferay']['postgresql']['version'] = "9.1"
default['liferay']['postgresql']['dir'] = "/etc/postgresql/#{default['liferay']['postgresql']['version']}/main"
default['liferay']['postgresql']['port'] = 5432
default['liferay']['postgresql']['admin_password'] = "postgres"
default['liferay']['postgresql']['user'] = "liferay_user"
default['liferay']['postgresql']['user_password'] = "liferay"
default['liferay']['postgresql']['database']['default'] = "liferay"

# Liferay installation
default['liferay']['download_url'] = "http://downloads.sourceforge.net/project/lportal/Liferay%20Portal/6.2.0%20GA1/liferay-portal-tomcat-6.2.0-ce-ga1-20131101192857659.zip?r=&ts=1383419991&use_mirror=garr"
default['liferay']['install_directory'] = "/opt"
default['liferay']['java_opts'] = "-Xms128m -Xmx1024m -XX:MaxPermSize=256m"
default['liferay']['port'] = 8087

# Portal configuration
default['liferay']['company_default_name'] = "algorythm"
default['liferay']['admin']['name'] = "Max Goltzsche"
default['liferay']['admin']['email'] = "max.goltzsche@gmail.com"


