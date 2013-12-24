package 'openssl'

execute 'Generate certificate' do
  command "openssl req -new -newkey rsa:4096 -days 2000 -nodes -x509 -subj '/C=DE/ST=Berlin/L=Berlin/O=algorythm/CN=algorythm.de' -keyout /etc/ssl/private/server.key -out /etc/ssl/certs/server.crt"
  not_if {File.exist?("/etc/ssl/private/server.key")}
end
