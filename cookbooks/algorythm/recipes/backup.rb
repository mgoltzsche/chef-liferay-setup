installDir = node['backup']['install_directory']
executable = "#{installDir}/backup.sh"

directory "#{installDir}/tasks" do
  owner 'root'
  group 'root'
  mode 0755
  recursive true
end

directory "#{installDir}/log" do
  owner 'root'
  group 'root'
  mode 0700
end

template "#{installDir}/backup-utils.inc.sh" do
  source 'backup-utils.inc.sh.erb'
  owner 'root'
  group 'root'
  mode 0744
end

template executable do
  source 'backup.sh.erb'
  owner 'root'
  group 'root'
  mode 0755
  variables({
    :backupDir => node['backup']['backup_directory']
  })
end

link "/usr/bin/backup" do
  to executable
end
