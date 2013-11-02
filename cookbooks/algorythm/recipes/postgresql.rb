unless ENV['LANGUAGE'] == "en_US.UTF-8" && ENV['LANG'] == "en_US.UTF-8" && ENV['LC_ALL'] == "en_US.UTF-8"
  execute "setup-locale" do
    command "locale-gen en_US.UTF-8 && dpkg-reconfigure locales"
    action :run
  end

  cookbook_file '/etc/default/locale'

  ENV['LANGUAGE'] = ENV['LANG'] = ENV['LC_ALL'] = "en_US.UTF-8"
end

package 'postgresql'

execute "Set postgres user password" do
  user 'postgres'
  code <<-EOH
echo "ALTER ROLE postgres ENCRYPTED PASSWORD '#{node['liferay']['postgresql']['admin_password']}';" | psql
  EOH
end

execute "Create liferay postgres user" do
  user 'postgres'
  exists <<-EOH
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
#    template 'template0'
#    encoding 'UTF8'
#    tablespace 'DEFAULT'
#    connection_limit '-1'
#    owner node['liferay']['postgresql']['user']
end
