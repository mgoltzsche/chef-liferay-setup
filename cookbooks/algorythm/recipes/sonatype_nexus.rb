usr = node['liferay']['user']
downloadDir = "/Downloads"
version = node['nexus']['version']
nexusWarFile = "#{downloadDir}/nexus-#{version}.war"
nexusExtractDir = "/tmp/nexus-#{version}"
nexusDeployDir = "#{node['liferay']['install_directory']}/liferay/webapps/nexus"
nexusHome = node['nexus']['home']
hostname = node['nexus']['hostname']

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

directory "#{nexusHome}/conf" do
  owner usr
  group usr
  mode 01755
end

execute "Extract Sonatype Nexus" do
  cwd downloadDir
  command "mkdir #{nexusExtractDir} && unzip -qd /tmp/nexus-#{version} #{nexusWarFile}"
  not_if {File.exist?(nexusExtractDir)}
end

execute "Deploy Sonatype Nexus" do
  user usr
  group usr
  command "cp -R #{nexusExtractDir} #{nexusDeployDir}"
  not_if {File.exist?(nexusDeployDir)}
end

file "#{nexusDeployDir}/WEB-INF/plexus.properties" do
  owner usr
  group usr
  mode 0644
  content <<-EOH
nexus-work=#{nexusHome}
security-xml-file=${nexus-work}/conf/security.xml
application-conf=${nexus-work}/conf

runtime=${bundleBasedir}
nexus-app=${runtime}

pr.encryptor.publicKeyPath=/apr/public-key.txt
  EOH
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
