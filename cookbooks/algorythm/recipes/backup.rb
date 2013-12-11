installDir = node['backup']['install_directory']
executable = "#{installDir}/backup.sh"

directory "#{installDir}/bin" do
  owner 'root'
  group 'root'
  mode 00755
  recursive true
end

directory "#{installDir}/tasks" do
  owner 'root'
  group 'root'
  mode 00755
end

template "#{installDir}/backup-pg.sh" do
  source 'backup-pg.sh.erb'
  owner 'root'
  group 'root'
  mode 00755
end

template "#{installDir}/backup-files.sh" do
  source 'backup-files.sh.erb'
  owner 'root'
  group 'root'
  mode 00755
end

template executable do
  source 'backup.sh.erb'
  owner 'root'
  group 'root'
  mode 00755
  variables({
    :backupDir => node['backup']['backup_directory']
  })
end

link "/usr/bin/backup" do
  to executable
end

link "#{installDir}/bin/backup" do
  to executable
end

link "#{installDir}/bin/backup-pg" do
  to "#{installDir}/backup-pg.sh"
end

link "#{installDir}/bin/backup-files" do
  to "#{installDir}/backup-files.sh"
end
