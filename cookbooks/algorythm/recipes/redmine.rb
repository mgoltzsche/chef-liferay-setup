usr = node['redmine']['user']
downloadDir = "/home/#{usr}/Downloads"
redmineZipFile = File.basename(URI.parse(node['redmine']['download_url']).path)
redmineExtractionDir = redmineZipFile.gsub(/(.*)\.zip/, '\1')
redmineHome = "#{node['redmine']['install_directory']}/#{redmineExtractionDir}";
redmineHomeLink = "#{node['redmine']['install_directory']}/redmine";
dbname = node['redmine']['postgresql']['database']

# --- Create Redmine system user ---
user usr do
  comment 'Redmine User'
  home "/home/#{usr}"
  shell '/bin/bash'
  supports :manage_home=>true
end

# --- Download Redmine
directory downloadDir do
  owner usr
  group usr
  mode 00755
  action :create
end

remote_file "#{downloadDir}/#{redmineZipFile}" do
  owner usr
  group usr
  source node['redmine']['download_url']
  action :create_if_missing
end

# --- Extract and link Redmine ---
execute "Extract Redmine" do
  cwd downloadDir
  user 'root'
  group 'root'
  command "unzip -qd #{node['redmine']['install_directory']} #{redmineZipFile}"
  not_if {File.exist?(redmineHome)}
  notifies :run, "execute[Create symlink and change owner]", :immediately
end

execute "Create symlink and change owner" do
  user 'root'
  group 'root'
  command <<-EOH
rm -rf #{node['redmine']['install_directory']}/redmine &&
ln -s #{redmineHome} #{redmineHomeLink} &&
chown -R #{usr}:#{usr} #{redmineHome}
  EOH
  action :nothing
end

# --- Configure redmine database ---
template "#{redmineHome}/config/database.yml" do
  owner usr
  group usr
  source "redmine.database.config"
  mode 01700
  variables({
    :database => node['redmine']['postgresql']['database'],
    :user => node['redmine']['postgresql']['user'],
    :password => node['redmine']['postgresql']['password']
  })
end

# --- Install Redmine ---
execute "Install bundler" do
  command "gem install bundler"
end

execute "Register thin gem for installation" do
  cwd redmineHome
  user usr
  group usr
  command 'echo "gem \'thin\'" > Gemfile.local'
end

execute "Install gems" do
  cwd redmineHome
  command "bundle install --without development test"
end

execute "Generate session store secret" do
  cwd redmineHome
  user usr
  group usr
  command "rake generate_secret_token"
end

execute "Create database '#{dbname}'" do
  user 'postgres'
  command "createdb '#{dbname}' -O #{node['redmine']['postgresql']['user']} -E UTF8 -T template0"
  not_if("psql -c \"SELECT datname FROM pg_catalog.pg_database WHERE datname='#{dbname}';\" | grep '#{dbname}'", :user => 'postgres')
end

execute "Create database structure" do
  cwd redmineHome
  user usr
  group usr
  command "RAILS_ENV=production rake db:migrate"
end

execute "Insert default database data" do
  cwd redmineHome
  user usr
  group usr
  command "RAILS_ENV=production REDMINE_LANG=en rake redmine:load_default_data"
end

execute "Configure file system permissions" do
  cwd redmineHome
  command "chmod -R 755 files log tmp public/plugin_assets"
end

# --- Configure thin application server ---

