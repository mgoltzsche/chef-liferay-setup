#!/bin/bash
# run as root

# Install RedHat's/Fedora's 389 directory server
apt-get install 389-ds-base
# Install LDAP utils (for ldapmodify)
apt-get install ldap-utils


# Decrease tcp timeout
echo "net.ipv4.tcp_keepalive_time = 600" >> /etc/sysctl.conf
sysctl -p # apply sysctl.conf changes immediately

# Increase open file limit
echo "*		 soft	 nofile		 4096" >> /etc/security/limits.conf
echo "*		 hard	 nofile		 4096" >> /etc/security/limits.conf
# restart required to apply changes


# Create new 389 directory server instance
setup-ds

# Let server listen on IPv4
echo "dn: cn=config" > nsslapd-listenhost.ldif
echo "changetype: modify" >> nsslapd-listenhost.ldif
echo "replace: nsslapd-listenhost" >> nsslapd-listenhost.ldif
echo "nsslapd-listenhost: 0.0.0.0" >> nsslapd-listenhost.ldif
ldapmodify -a -x -h dev.algorythm.de -p 389 -D cn="manager" -w maximum! -f nsslapd-listenhost.ldif
rm nsslapd-listenhost.ldif
service dirsrv restart


# Add system user e.g. with the following LDIF (using Apache Directory Studio):
dn: cn=devilopa,ou=People,dc=algorythm,dc=de
objectClass: simpleSecurityObject
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
cn: devilopa
sn: Goltzsche
userPassword:: e3NzaGEyNTZ9WjFESCtZcG9aRE5SUTNlR1NqVWRVM2JJM3k1Q1FyVDQvUURiS
 URxZmFBVWVsRlg5aC9FMmtRPT0=
mail: max.goltzsche@gmail.com

# ... encrypt password with SHA-256
