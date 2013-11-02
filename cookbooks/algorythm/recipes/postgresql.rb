unless ENV['LANGUAGE'] == "en_US.UTF-8" && ENV['LANG'] == "en_US.UTF-8" && ENV['LC_ALL'] == "en_US.UTF-8"
  execute "setup-locale" do
    command "locale-gen en_US.UTF-8 && dpkg-reconfigure locales"
    action :run
  end

  cookbook_file '/etc/default/locale'

  ENV['LANGUAGE'] = ENV['LANG'] = ENV['LC_ALL'] = "en_US.UTF-8"
end

package 'postgresql'

# Write config files
template "#{node['liferay']['postgresql']['dir']}/postgresql.conf" do
  source "postgresql.conf.erb"
  owner "postgres"
  group "postgres"
  mode 0600
#  notifies :reload, 'service[postgresql]', :immediately
end

# Restart postgresql
service 'postgresql' do
  action :restart
end

# Configure users
execute "Set postgres admin password" do
  user 'postgres'
  command "psql -U postgres -c \"ALTER ROLE postgres ENCRYPTED PASSWORD '#{node['liferay']['postgresql']['admin_password']}';\""
end

execute "Create liferay postgres user '#{node['liferay']['postgresql']['user']}'" do
  user 'postgres'
  command "psql -U postgres -c \"CREATE USER #{node['liferay']['postgresql']['user']};\""
  not_if("psql -U postgres -c \"SELECT * FROM pg_user WHERE usename='#{node['liferay']['postgresql']['user']}';\" | grep #{node['liferay']['postgresql']['user']}", :user => 'postgres')
end

execute "Set postgres user password of '#{node['liferay']['postgresql']['user']}'" do
  user 'postgres'
  command "psql -U postgres -c \"ALTER ROLE #{node['liferay']['postgresql']['user']} ENCRYPTED PASSWORD '#{node['liferay']['postgresql']['admin_password']}';\""
end

# Create databases
node['liferay']['postgresql']['database'].each do |db, name|
  execute "Create database '#{name}'" do
    user 'postgres'
    command "createdb '#{name}' -O #{node['liferay']['postgresql']['user']} -E UTF8 -T template0"
    not_if("psql -U postgres -c \"SELECT datname FROM pg_catalog.pg_database WHERE datname='#{name}';\" | grep '#{name}'", :user => 'postgres')
  end
end
