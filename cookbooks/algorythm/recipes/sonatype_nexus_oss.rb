usr = node['liferay']['user']
downloadDir = "/home/#{usr}/Downloads"
version = node['nexus']['version']
nexusWarFile = "#{downloadDir}/nexus-#{version}.war"
nexusDeployWarFile = "#{node['liferay']['install_directory']}/liferay/deploy/nexus.war"

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
