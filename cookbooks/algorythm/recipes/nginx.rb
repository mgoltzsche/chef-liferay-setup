# --- Install nginx
package 'nginx'

template "/etc/nginx/nginx.conf" do
  source "nginx.conf.erb"
  mode 00644
end
