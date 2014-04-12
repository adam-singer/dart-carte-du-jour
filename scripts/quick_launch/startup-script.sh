#!/usr/bin/env bash
set -x

# TODO(adam): hack for non ssh friendly firewalls. 
# update the sshd_config to open port 443
sed -i '1i Port 443' /etc/ssh/sshd_config 

# restart sshd
/etc/init.d/ssh restart

export DARTSDK=$(curl http://metadata/computeMetadata/v1beta1/instance/attributes/dartsdk)
export PACKAGE=$(curl http://metadata/computeMetadata/v1beta1/instance/attributes/package)
export VERSION=$(curl http://metadata/computeMetadata/v1beta1/instance/attributes/version)
export MODE=$(curl http://metadata/computeMetadata/v1beta1/instance/attributes/mode)

# gsutil cp -r gs://dart-carte-du-jour/configurations/github_private_repo_pull ~/
# sudo -H -u financeCoding bash -c 'echo "I am $USER, with uid $UID"' 
sudo -E -H -u financeCoding bash -c 'gsutil cp -r gs://dart-carte-du-jour/configurations/github_private_repo_pull ~/ && cd ~/github_private_repo_pull && bash ./clone_project.sh'
sudo -E -H -u financeCoding bash -c 'source /etc/profile && cd ~/github_private_repo_pull/dart-carte-du-jour && pub install && dart bin/package_daemon.dart --verbose --mode $MODE --sdk  $DARTSDK --package $PACKAGE --version $VERSION'