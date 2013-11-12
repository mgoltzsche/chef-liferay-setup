# --- Install nginx
package 'nginx'

# proxy_cache_path /usr/share/nginx/cache levels=1:2 keys_zone=algorythm-cache:8m max_size=1000m inactive=600m;
# proxy_temp_path /usr/share/nginx/cache/tmp;

execute "Configure proxy cache path" do
  command <<-EOH
echo "proxy_cache_path /usr/share/nginx/cache levels=1:2 keys_zone=algorythm-cache:8m max_size=1000m inactive=600m;" > /etc/nginx/nginx.conf &&
echo "proxy_temp_path /usr/share/nginx/cache/tmp;" > /etc/nginx/nginx.conf
  EOH
  not_if 'grep -i "proxy_cache_path" /etc/nginx/nginx.conf'
end
