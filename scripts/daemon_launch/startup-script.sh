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
	set -x
	startup_script_log=gs://dart-carte-du-jour/build_logs/`hostname`-startupscript.log
	retry_wrapper gsutil cp /var/log/startupscript.log $startup_script_log
}

# TODO(adam): move functionality into dart scripts instead of shell scripts. 
function shutdown_instance () {
	set -x
	copy_startup_log

	export AUTOSHUTDOWN=$(curl http://metadata/computeMetadata/v1beta1/instance/attributes/autoshutdown)
	
	if [[ $AUTOSHUTDOWN -eq "1" ]]; then
		hostname=`uname -n`
		echo "Deleting instance ......... $hostname"
		retry_wrapper gcutil deleteinstance -f --delete_boot_pd --zone us-central1-a $hostname
	fi 
}

function fetch_latest_dart_sdk () {
	# remove dartsdk
	rm -rf /dart-sdk

	# Download the latest dart sdk
	wget http://storage.googleapis.com/dart-archive/channels/dev/release/latest/sdk/dartsdk-linux-x64-release.zip -O /tmp/dartsdk-linux-x64-release.zip 
  # wget http://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip -O /tmp/dartsdk-linux-x64-release.zip 
  
	# Unpack the dart sdk
	unzip -d / /tmp/dartsdk-linux-x64-release.zip

	# Make the sdk readable 
	chmod -R go+rx /dart-sdk
}

# TODO(adam): hack for non ssh friendly firewalls. 
# update the sshd_config to open port 443
sed -i '1i Port 443' /etc/ssh/sshd_config 

# restart sshd
/etc/init.d/ssh restart

# upgrade dart sdk to latest
fetch_latest_dart_sdk

# clone project
sudo -E -H -u financeCoding bash -c 'cd ~/ && git clone https://github.com/financeCoding/dart-carte-du-jour.git'

# get config file
sudo -E -H -u financeCoding bash -c 'cd ~/ && gsutil cp gs://dart-carte-du-jour/configurations/config.json ~/dart-carte-du-jour/bin/config.json'

# get private key
sudo -E -H -u financeCoding bash -c 'cd ~/ && gsutil cp gs://dart-carte-du-jour/configurations/rsa_private_key.pem ~/dart-carte-du-jour/bin/rsa_private_key.pem'

# start service
sudo -E -H -u financeCoding bash -c 'cd ~/ && rm -rf ~/.pub-cache/; source /etc/profile && cd ~/dart-carte-du-jour && pub install && dart bin/daemon_isolate.dart'

shutdown_instance
