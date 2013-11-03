package 'nginx'

# Create cache directory
directory '/usr/share/nginx/cache' do
  owner 'www-data'
  group 'www-data'
  mode 00744
  action :create
end

# Declare nginx service
service 'nginx' do
  action :nothing
end

# Set default vhost and pages
cookbook_file '/usr/share/nginx/www/index.html'
cookbook_file '/usr/share/nginx/www/50x.html'

template "/etc/nginx/sites-available/default" do
  source "default.erb"
  mode 00700
  owner 'root'
  group 'root'
  variables({
    :port => node['liferay']['port']
  })
  notifies :reload, 'service[nginx]', :immediately
end
