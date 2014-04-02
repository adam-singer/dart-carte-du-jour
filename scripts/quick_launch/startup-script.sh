#!/usr/bin/env bash
set -x

# TODO(adam): hack for non ssh friendly firewalls. 
# update the sshd_config to open port 443
sed -i '1i Port 443' /etc/ssh/sshd_config 

# restart sshd
/etc/init.d/ssh restart
