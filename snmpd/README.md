# snmpd

Installation/configuration example on how to set up snmpd on a Debian server:

1. `apt -y install snmpd.service`
1. `systemctl stop snmpd.service`
1. Install `distro` to /usr/local/bin
1. Create a v3 AuthPriv read-only user using something to the like of `net-snmp-create-v3-user -ro -A my_authpass -X my_privpass -a SHA -x AES netadmin`
1. `systemctl start snmpd`
1. Even when using encryption and passwords, it's best practice to additinally lock the port down to the querying IP address
