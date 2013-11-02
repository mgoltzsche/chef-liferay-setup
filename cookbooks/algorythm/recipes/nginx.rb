package 'nginx'

directory '/usr/share/nginx/cache' do
  owner 'root'
  group 'root'
  mode 00644
  action :create
end

cookbook_file '/etc/nginx/sites-available/default'
cookbook_file '/usr/share/nginx/www/index.html'
cookbook_file '/usr/share/nginx/www/50x.html'

# restart nginx
service 'nginx' do
  action :restart
end
