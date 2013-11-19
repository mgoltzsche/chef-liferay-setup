# --- Install prerequisites ---
package 'imagemagick'
package 'unzip'
package 'openjdk-7-jdk'

hostname = node['hostname']
domainname = node['domainname']
maxOpenFiles = node['max_open_files']
tcpTimeout = node['tcp_timeout']

# --- Adjust sytem's TCP timeout & open file limits settings ---
execute "Set TCP timeout" do
  command <<-EOH
echo "net.ipv4.tcp_keepalive_time = 600" >> /etc/sysctl.conf &&
sysctl -p
  EOH
  not_if('cat /etc/sysctl.conf | grep "net\\.ipv4\\.tcp_keepalive_time = 600"')
end

file "/etc/security/limits.conf" do # Restart required to apply changes
  content <<-EOH
*		 soft	 nofile		 #{maxOpenFiles}
*		 hard	 nofile		 #{maxOpenFiles}
  EOH
end

# --- Set host name ---
file '/etc/hostname' do
  content "#{hostname}\n"
end

file '/etc/hosts' do
  content "127.0.0.1 localhost #{hostname} #{hostname}.#{domainname} #{domainname}\n"
end

service 'hostname' do
  action :restart
end
