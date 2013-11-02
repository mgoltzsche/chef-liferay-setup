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

# restart postgresql
service 'postgresql' do
  action :restart
end

# Configure users
execute "Set postgres user password" do
  user 'postgres'
  command <<-EOH
psql -U postgres -c "ALTER ROLE postgres ENCRYPTED PASSWORD '#{node['liferay']['postgresql']['admin_password']}';"
  EOH
end

execute "Create liferay postgres user" do
  user 'postgres'
  exists = <<-EOH
psql -U postgres -c "SELECT * FROM pg_user WHERE usename='#{node['liferay']['postgresql']['user']}';" | grep #{node['liferay']['postgresql']['user']}
  EOH
  command <<-EOH
psql -U postgres -c "CREATE USER #{node['liferay']['postgresql']['user']};"
  EOH
  not_if !exists
end

execute "Set liferay postgres user password" do
  user 'postgres'
  command <<-EOH
psql -U postgres -c "ALTER ROLE #{node['liferay']['postgresql']['user']} ENCRYPTED PASSWORD '#{node['liferay']['postgresql']['admin_password']}';"
  EOH
end

# create databases
node['liferay']['postgresql']['database'].each do |db, name|
  execute "Create database #{name}" do
    user 'postgres'
    exists = <<-EOH
psql -U postgres -c "SELECT datname FROM pg_catalog.pg_database WHERE datname='#{name}';" | grep #{name}
    EOH
    command <<-EOH
createdb #{name} -O #{node['liferay']['postgresql']['user']} -E UTF8 -T template0
    EOH
    not_if exists
  end
end
