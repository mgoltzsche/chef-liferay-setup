# --- Configure locale: en_US.UTF-8 ---
unless ENV['LANGUAGE'] == "en_US.UTF-8" && ENV['LANG'] == "en_US.UTF-8" && ENV['LC_ALL'] == "en_US.UTF-8"
  execute "setup-locale" do
    command "locale-gen en_US.UTF-8 && dpkg-reconfigure locales"
    action :run
  end

  cookbook_file '/etc/default/locale'

  ENV['LANGUAGE'] = ENV['LANG'] = ENV['LC_ALL'] = "en_US.UTF-8"
end

# --- Install postgresql ---
package 'postgresql'

# --- Write config ---
template "#{node['liferay']['postgresql']['dir']}/postgresql.conf" do
  source "postgresql.conf.erb"
  owner "postgres"
  group "postgres"
  mode 0600
end

# --- (Re)start postgresql ---
service 'postgresql' do
  action :restart
end
