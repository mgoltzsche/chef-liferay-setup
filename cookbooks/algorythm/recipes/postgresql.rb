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
echo "ALTER ROLE postgres ENCRYPTED PASSWORD '#{node['liferay']['postgresql']['admin_password']}';" | psql
  EOH
end

execute "Create liferay postgres user" do
  user 'postgres'
  exists = <<-EOH
echo "SELECT * FROM pg_user WHERE usename='#{node['liferay']['postgresql']['user']}';" | psql | grep #{node['liferay']['postgresql']['user']}
  EOH
  command <<-EOH
echo "CREATE USER #{node['liferay']['postgresql']['user']};" | psql
  EOH
  not_if exists
end

execute "Set liferay postgres user password" do
  user 'postgres'
  command <<-EOH
echo "ALTER ROLE #{node['liferay']['postgresql']['user']} ENCRYPTED PASSWORD '#{node['liferay']['postgresql']['admin_password']}';" | psql
  EOH
end

# create databases
node['liferay']['postgresql']['database'].each do |db, name|
  execute "Create database #{db}" do
    user 'postgres'
    exists = <<-EOH
psql -l | grep #{db}
    EOH
    command <<-EOH
createdb #{db} -D DEFAULT -E UTF8 -O #{node['liferay']['postgresql']['user']} -T template0
    EOH
    not_if exists
  end
end
