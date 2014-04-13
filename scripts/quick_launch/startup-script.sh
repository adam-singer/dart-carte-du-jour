#!/usr/bin/env bash
set -x

declare -r maxretry=10
declare -r waittime=5
declare retrycounter=0
 
function retry_wrapper() {
	local cmd=$1 ; shift
	retry $cmd "$@"
	local s=$?
	retrycounter=0
	return $s
}
 
function retry() {
	set +o errexit
	local cmd=$1 ; shift
	$cmd "$@"
	local s=$?
	if [ $s -ne 0 -a $retrycounter -lt $maxretry ] ; then
		retrycounter=$(($retrycounter+1))
		echo "Retrying"
		sleep $((1+$retrycounter*$retrycounter*$waittime))
		retry $cmd "$@"
	fi

	return $s
}

function copy_startup_log () {
	startup_script_log=gs://dart-carte-du-jour/build_logs/`hostname`-startupscript.log
	gsutil cp /var/log/startupscript.log $startup_script_log
	status=$?
	
	if [[ $status != 0 ]] ; then
		echo "Failed to copy /var/log/startupscript.log $startup_script_log $status"
	fi
}

# TODO(adam): move functionality into dart scripts instead of shell scripts. 
function shutdown_instance () {
	copy_startup_log

	export AUTOSHUTDOWN=$(curl http://metadata/computeMetadata/v1beta1/instance/attributes/autoshutdown)
	
	if [[ $AUTOSHUTDOWN -eq "1" ]]; then
		hostname=`uname -n`
		echo "Deleting instance ......... $hostname"
		retry_wrapper gcutil deleteinstance -f --delete_boot_pd --zone us-central1-a $hostname
	fi 
}

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

shutdown_instance
