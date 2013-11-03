require 'uri'

# --- Create Liferay system user (not required) ---
user node['liferay']['user'] do
  comment 'Liferay User'
  home "/home/#{node['liferay']['user']}"
  shell '/bin/bash'
  supports :manage_home=>true
end

# --- Download and install Liferay ---
downloadDir = "/tmp/liferay_downloads"
liferayZipFile = File.basename(URI.parse(node['liferay']['download_url']).path)
liferayExtractionDir = liferayZipFile.gsub(/liferay-portal-[\w]+-(([\d]+\.?)+-[\w]+(-[\w]+)?)-[\d]+.zip/, 'liferay-portal-\1')
liferayHome = "#{node['liferay']['install_directory']}/#{liferayExtractionDir}";

directory downloadDir do
  owner 'root'
  group 'root'
  mode 00744
  action :create
end

remote_file "#{downloadDir}/#{liferayZipFile}" do
  owner 'root'
  group 'root'
  source node['liferay']['download_url']
  action :create_if_missing
end

execute "Extract Liferay" do
  cwd downloadDir
  user 'root'
  group 'root'
  command "unzip -qd #{node['liferay']['install_directory']} #{liferayZipFile}"
  not_if {File.exist?(liferayHome)}
  notifies :run, "execute[Create symlinks]", :immediately
end

execute "Create symlinks" do
  user 'root'
  group 'root'
  command <<-EOH
rm -rf #{node['liferay']['install_directory']}/liferay &&
ln -s #{liferayHome} #{node['liferay']['install_directory']}/liferay &&
ln -s #{liferayHome}/$(ls #{liferayHome} | grep tomcat) #{liferayHome}/tomcat
  EOH
  action :nothing
end

# --- Clean up Liferay installation ---
Dir.glob("#{node['liferay']['install_directory']}/liferay/tomcat/bin/*.bat").each do |bat_file|
  file bat_file do
    action :delete
  end
end

directory "#{node['liferay']['install_directory']}/liferay/tomcat/webapps/welcome-theme" do
  recursive true
  action :delete
end

directory "#{node['liferay']['install_directory']}/liferay/tomcat/webapps/resources-importer-web" do
  recursive true
  action :delete
end
