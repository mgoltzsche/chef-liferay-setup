# --- Install prerequisites ---
package 'imagemagick'
package 'openjdk-7-jre-headless'

# --- Import recipes ---
include_recipe 'unzip'
include_recipe 'postgresql'
include_recipe 'nginx'

# --- Set user ---
user node['liferay']['user'] do
  comment 'Liferay User'
  home "/home/#{node['liferay']['user']}"
  shell '/bin/bash'
  supports :manage_home=>true
end

# --- Set host name ---
hostname = node['liferay']['hostname']

file '/etc/hostname' do
  content "#{hostname}\n"
end

service 'hostname' do
  action :restart
end

file '/etc/hosts' do
  content "127.0.0.1 localhost #{hostname}\n"
end

# --- Deploy a configuration file ---
# For longer files, when using 'content "..."' becomes too
# cumbersome, we can resort to deploying separate files:

#cookbook_file '/etc/apache2/apache2.conf'

# This will copy cookbooks/op/files/default/apache2.conf (which
# you'll have to create yourself) into place. Whenever you edit
# that file, simply run "./deploy.sh" to copy it to the server.
