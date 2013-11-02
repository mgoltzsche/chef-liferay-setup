# Hostname
default['liferay']['hostname'] = 'dev.algorythm.de'

# User
default['liferay']['user'] = "liferay"
default['liferay']['group'] = "liferay"

# Database: Postgres
default['liferay']['postgresql']['admin_password'] = "postgres"
default['liferay']['postgresql']['user'] = "liferay_user"
default['liferay']['postgresql']['user_password'] = "liferay"
default['liferay']['postgresql']['database']['default'] = "lportal"
