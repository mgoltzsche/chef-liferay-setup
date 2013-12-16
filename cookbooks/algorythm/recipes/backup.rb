installDir = node['backup']['install_directory']
executable = "#{installDir}/backup.sh"

directory "#{installDir}/bin" do
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

directory "#{installDir}/tasks" do
  owner 'root'
  group 'root'
  mode 0755
end

template "#{installDir}/backup-pg.sh" do
  source 'backup-pg.sh.erb'
  owner 'root'
  group 'root'
  mode 0755
end

template "#{installDir}/backup-file.sh" do
  source 'backup-file.sh.erb'
  owner 'root'
  group 'root'
  mode 0755
end

template "#{installDir}/backup-directory.sh" do
  source 'backup-directory.sh.erb'
  owner 'root'
  group 'root'
  mode 0755
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

link "#{installDir}/bin/backup" do
  to executable
end

link "#{installDir}/bin/backup-pg" do
  to "#{installDir}/backup-pg.sh"
end

link "#{installDir}/bin/backup-files" do
  to "#{installDir}/backup-files.sh"
end
