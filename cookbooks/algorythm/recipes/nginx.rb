# --- Install nginx
package 'nginx'

template '/etc/nginx/nginx.conf' do
  source 'nginx.conf.erb'
  mode 00644
end

template '/etc/nginx/proxy_params' do
  source 'nginx.proxy_params.erb'
  mode 0644
end

directory '/usr/share/nginx/cache' do
  owner 'www-data'
  group 'www-data'
  mode 0744
end

directory '/var/log/nginx' do
  owner 'root'
  group 'www-data'
  mode 0770
end

# --- Configure config backup ---
template "#{node['backup']['install_directory']}/tasks/backup-nginx.sh" do
  source 'backup-nginx.sh.erb'
  owner 'root'
  group 'root'
  mode 0744
end
