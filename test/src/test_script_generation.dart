library test_script_generation;

import 'dart:convert';

import 'package:test/test.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

void main() {
  group('buildStartupScript', () {
    test('startup_script.mustache', () {
      String unittestPackageModel =
          """
      {
    "name": "unittest",
    "uploaders": [
        "dgrove@google.com",
        "jmesserly@google.com"
    ],
    "versions": [
        "0.10.0",
        "0.10.1",
        "0.10.1+1"
    ]
}""";
      Package package = new Package.fromJson(JSON.decode(unittestPackageModel));

      String _sdkPath = "/dart-sdk";
      GoogleComputeEngineConfig _googleComputeEngineConfig =
          new GoogleComputeEngineConfig("1234", "1234", "foo@bar.com", "key");

      ClientBuilderConfig clientBuilderConfig = new ClientBuilderConfig(
          _sdkPath, _googleComputeEngineConfig, [package]);

      var startupScript = buildMultiStartupScript(
          "packages/dart_carte_du_jour/multi_package_startup_script.mustache",
          clientBuilderConfig.storeFileName());
      expect(startupScript, equals(
          r"""#!/usr/bin/env bash
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
  startup_script_log=gs://www.dartdocs.org/buildlogs/`hostname`-startupscript.log
  retry_wrapper gsutil -h 'Content-Type:text/plain' cp -z 'log' -a public-read /var/log/startupscript.log $startup_script_log
}
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
  rm -rf /dart-sdk
  wget http://storage.googleapis.com/dart-archive/channels/dev/release/latest/sdk/dartsdk-linux-x64-release.zip -O /tmp/dartsdk-linux-x64-release.zip
  # wget http://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip -O /tmp/dartsdk-linux-x64-release.zip
  unzip -d / /tmp/dartsdk-linux-x64-release.zip
  chmod -R go+rx /dart-sdk
  /dart-sdk/bin/dart --version
}
function setup_proxy () {
  #daemon-isolate is the instance name of the proxy gateway
  sudo echo "export http_proxy=\"http://daemon-isolate:3128\"" >> /etc/profile.d/proxy.sh
  sudo echo "export https_proxy=\"http://daemon-isolate:3128\"" >> /etc/profile.d/proxy.sh
  sudo echo "export ftp_proxy=\"http://daemon-isolate:3128\"" >> /etc/profile.d/proxy.sh
  sudo echo "export no_proxy=169.254.169.254,metadata,metadata.google.internal" >> /etc/profile.d/proxy.sh

  # Configure boto with proxy settings. gcloud tools depend on boto configuration.
  sudo echo "[Boto]" >> /etc/boto.cfg
  sudo echo "proxy = daemon-isolate" >> /etc/boto.cfg
  sudo echo "proxy_port = 3128" >> /etc/boto.cfg


  # Update sudoers to pass these env variables through
  sudo cp /etc/sudoers /tmp/sudoers.new
  sudo chmod 640 /tmp/sudoers.new
  sudo echo "Defaults env_keep += \"ftp_proxy http_proxy https_proxy no_proxy"\" >>/tmp/sudoers.new
  sudo chmod 440 /tmp/sudoers.new
  sudo visudo -c -f /tmp/sudoers.new && mv -f /tmp/sudoers.new /etc/sudoers

  source /etc/profile.d/proxy.sh
}
sed -i '1i Port 443' /etc/ssh/sshd_config
/etc/init.d/ssh restart
setup_proxy
fetch_latest_dart_sdk
sudo -E -H -u financeCoding bash -c 'cd ~/ && git clone https://github.com/financeCoding/dart-carte-du-jour.git'
sudo -E -H -u financeCoding bash -c 'cd ~/ && gsutil cp gs://dart-carte-du-jour/configurations/config.json ~/dart-carte-du-jour/bin/config.json'
sudo -E -H -u financeCoding bash -c 'cd ~/ && gsutil cp gs://dart-carte-du-jour/configurations/rsa_private_key.pem ~/dart-carte-du-jour/bin/rsa_private_key.pem'
sudo -E -H -u financeCoding bash -c 'cd ~/ && gsutil cp gs://dart-carte-du-jour/client_builder_configurations/"""
          + clientBuilderConfig.id + r""".json ~/dart-carte-du-jour/bin/""" +
          clientBuilderConfig.id +
          r""".json'
sudo -E -H -u financeCoding bash -c 'cd ~/ && source /etc/profile && cd ~/dart-carte-du-jour && dart --version'
sudo -E -H -u financeCoding bash -c 'cd ~/ && rm -rf ~/pub-cache; source /etc/profile && cd ~/dart-carte-du-jour && pub install && dart bin/client_builder.dart --verbose --clientConfig bin/"""
          + clientBuilderConfig.id + r""".json'
shutdown_instance
"""));
    });
  });
}
