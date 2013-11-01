unless ENV['LANGUAGE'] == "en_US.UTF-8" && ENV['LANG'] == "en_US.UTF-8" && ENV['LC_ALL'] == "en_US.UTF-8"
  execute "setup-locale" do
    command "locale-gen en_US.UTF-8 && dpkg-reconfigure locales"
    action :run
  end

  cookbook_file '/etc/default/locale'

  ENV['LANGUAGE'] = ENV['LANG'] = ENV['LC_ALL'] = "en_US.UTF-8"
end

include_recipe "postgresql::server"
include_recipe "database::postgresql"

postgresql_connection_info = {:host => "127.0.0.1",
                              :port => node['postgresql']['config']['port'],
                              :username => 'postgres',
                              :password => node['postgresql']['password']['postgres']}

# create the liferay postgresql user but grant no privileges
postgresql_database_user node['liferay']['postgresql']['user'] do
  connection postgresql_connection_info
  password node['liferay']['postgresql']['user_password']
  action :create
end

# create databases
node['liferay']['postgresql']['database'].each do |db, name|
        postgresql_database name do
         connection postgresql_connection_info
    template 'template0'
    encoding 'UTF8'
    tablespace 'DEFAULT'
    connection_limit '-1'
    owner node['liferay']['postgresql']['user']
    action :create
        end
end
