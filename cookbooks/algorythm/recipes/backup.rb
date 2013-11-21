executable = "#{node['backup']['install_directory']}/backup.sh"

directory "#{node['backup']['install_directory']}/scripts" do
  owner 'root'
  group 'root'
  mode 00755
  recursive true
end

template executable do
  source "backup.sh.erb"
  owner 'root'
  group 'root'
  mode 00700
  variables({
    :installDir => node['backup']['install_directory'],
    :backupDir => node['backup']['backup_directory']
  })
end

link "/usr/bin/backup" do
  to executable
end
