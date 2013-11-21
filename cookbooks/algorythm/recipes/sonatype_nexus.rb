usr = node['liferay']['user']
downloadDir = "/Downloads"
version = node['nexus']['version']
nexusWarFile = "#{downloadDir}/nexus-#{version}.war"
nexusExtractDir = "/tmp/nexus-#{version}"
nexusDir = "#{node['liferay']['install_directory']}/liferay/webapps/nexus"
nexusDeployWAR = "#{node['liferay']['home']}/deploy/nexus.war"
nexusHome = node['nexus']['home']
nexusHomeEscaped = nexusHome.dup.gsub!('/', '\\/')
hostname = node['nexus']['hostname']

package 'zip'

# --- Download & deploy Nexus OSS ---
remote_file nexusWarFile do
  source "http://www.sonatype.org/downloads/nexus-#{version}.war"
  action :create_if_missing
end

directory nexusHome do
  owner usr
  group usr
  mode 01755
end

execute "Extract Sonatype Nexus" do
  user usr
  group usr
  cwd downloadDir
  command "mkdir #{nexusExtractDir} && unzip -qd /tmp/nexus-#{version} #{nexusWarFile}"
  not_if {File.exist?(nexusExtractDir)}
end

execute "Deploy Sonatype Nexus" do
  user usr
  group usr
  command <<-EOH
sed -i 's/^\s*nexus-work\s*=.*/nexus-work=#{nexusHomeEscaped}/' #{nexusExtractDir}/WEB-INF/plexus.properties &&
zip -r #{nexusDeployWAR} #{nexusExtractDir}
  EOH
  not_if {File.exist?(nexusDir)}
end

# --- Configure nginx ---
template "/etc/nginx/sites-available/#{hostname}" do
  source "nexus.nginx.vhost.erb"
  mode 00700
  variables({
    :hostname => hostname,
    :http_port => node['liferay']['http_port'],
    :https_port => node['liferay']['https_port']
  })
end

link "/etc/nginx/sites-enabled/#{hostname}" do
  to "/etc/nginx/sites-available/#{hostname}"
end

# --- Restart nginx ---
service "nginx" do
  action :restart
end
