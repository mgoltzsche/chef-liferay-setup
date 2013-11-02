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
