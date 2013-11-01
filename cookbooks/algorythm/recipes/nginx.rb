package 'nginx'

directory '/usr/share/nginx/www' do
  action :delete
end

directory '/var/www/http' do
  owner 'root'
  group 'root'
  mode 00644
  action :create
end

directory '/var/www/cache' do
  owner 'root'
  group 'root'
  mode 00644
  action :create
end

cookbook_file '/etc/nginx/sites-available/default'
cookbook_file '/var/www/http/index.html'
cookbook_file '/var/www/http/50x.html'

service 'nginx' do
  action :restart
end
