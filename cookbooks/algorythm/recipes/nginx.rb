# --- Install nginx
package 'nginx'

template "/etc/nginx/nginx.conf" do
  source "nginx.conf.erb"
  mode 00644
end

template "/etc/nginx/proxy_params" do
  source "nginx.proxy_params.erb"
  mode 00644
end
