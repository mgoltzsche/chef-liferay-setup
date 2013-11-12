usr = node['liferay']['user']
downloadDir = "/home/#{usr}/Downloads"
version = node['nexus']['version']
nexusWarFile = "#{downloadDir}/nexus-#{version}.war"
nexusDeployDir = "#{node['liferay']['install_directory']}/liferay/tomcat/webapps/nexus"
hostname = node['nexus']['hostname']

# --- Download & deploy Nexus OSS ---
remote_file nexusWarFile do
  owner usr
  group usr
  source "http://www.sonatype.org/downloads/nexus-#{version}.war"
  action :create_if_missing
end

#execute "Deploy Nexus OSS" do
#  cwd downloadDir
#  user usr
#  group usr
#  command "cp #{nexusWarFile} #{nexusDeployWarFile}"
#end

directory nexusDeployDir do
  owner usr
  group usr
  mode 00755
  action :create
end

execute "Deploy Nexus OSS" do
  cwd downloadDir
  user usr
  group usr
  command "unzip -qd #{nexusDeployDir} #{nexusWarFile}"
end

# --- Configure Nexus OSS to run under / context ---
template "#{nexusDeployDir}/META-INF/context.xml" do
  source "nexus.context.xml.erb"
  mode 00744
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

# --- Restart nginx ---
service "nginx" do
  action :restart
end
