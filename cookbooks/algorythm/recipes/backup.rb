installDir = node['backup']['install_directory']

executable = "#{installDir}/backup.sh"

directory "#{installDir}/scripts" do
  owner 'root'
  group 'root'
  mode 00755
  recursive true
end

template executable do
  source "backup.sh.erb"
  owner 'root'
  group 'root'
  mode 00755
  variables({
    :installDir => node['backup']['install_directory'],
    :backupDir => node['backup']['backup_directory']
  })
end

link "/usr/bin/backup" do
  to executable
end
