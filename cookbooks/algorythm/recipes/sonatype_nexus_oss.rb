usr = node['liferay']['user']
downloadDir = "/home/#{usr}/Downloads"
version = node['nexus']['version']
nexusWarFile = "#{downloadDir}/nexus-#{version}.war"
nexusDeployWarFile = "#{node['liferay']['install_directory']}/liferay/deploy/nexus.war"
hostname = node['nexus']['hostname']

remote_file nexusWarFile do
  owner usr
  group usr
  source "http://www.sonatype.org/downloads/nexus-#{version}.war"
  action :create_if_missing
end

execute "Deploy Nexus OSS" do
  cwd downloadDir
  user usr
  group usr
  command "cp #{nexusWarFile} #{nexusDeployWarFile}"
end

# --- Configure nginx vhost ---
template "/etc/nginx/sites-available/#{hostname}" do
  source "nexus.nginx.vhost.erb"
  mode 00700
  variables({
    :hostname => hostname,
    :port => node['liferay']['port']
  })
end

link "/etc/nginx/sites-enabled/#{hostname}" do
  to "/etc/nginx/sites-available/#{hostname}"
end
