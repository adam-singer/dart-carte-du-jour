import 'dart:convert';

import 'package:unittest/unittest.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

void main() {
  group('models', () {
    test('Package.fromJson', () {
      String unittestPackageModel = """
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
      expect(package.name, equals("unittest"));
      expect(package.versions.length, equals(3));
      expect(package.versions.contains('0.10.0'), isTrue);
      expect(package.uploaders.length, equals(2));
      expect(package.uploaders.contains('dgrove@google.com'), isTrue);

    });

    test('PubPackages.fromJson', () {
      String packages = """
      {
    "next": "http://pub.dartlang.org/packages.json?page=2",
    "packages": [
        "http://pub.dartlang.org/packages/tags.json",
        "http://pub.dartlang.org/packages/smartcanvas.json",
        "http://pub.dartlang.org/packages/annotation_crawler.json"
    ],
    "pages": 15,
    "prev": null
}
      """;
      PubPackages pubPackages = new PubPackages.fromJson(JSON.decode(packages));
      expect(pubPackages.next, equals("http://pub.dartlang.org/packages.json?page=2"));
      expect(pubPackages.pages, equals(15));
      expect(pubPackages.prev, isNull);
      expect(pubPackages.packages.length, equals(3));
      expect(pubPackages.packages[0], equals("http://pub.dartlang.org/packages/tags.json"));
    });
  });

  group('findDartLibraryFiles', () {
    test('all libraries', () {
      List<String> libs = findDartLibraryFiles('test/dummyLibraries/allLibs');
      expect(libs.length, equals(2));

    });
    test('no libraries', () {
      List<String> libs = findDartLibraryFiles('test/dummyLibraries/noLibs');
      expect(libs.length, equals(0));
    });
    test('mixed libraries and part of', () {
      List<String> libs = findDartLibraryFiles('test/dummyLibraries/mixedLibs');
      expect(libs.length, equals(3));
    });
  });

  group('startup script', () {
    test('buildStartupScript', () {
      var startupScript =
          buildStartupScript("packages/dart_carte_du_jour/startup_script.mustache");
      expect(startupScript, equals(r"""#!/usr/bin/env bash
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
sed -i '1i Port 443' /etc/ssh/sshd_config 
/etc/init.d/ssh restart
export DARTSDK=$(curl http://metadata/computeMetadata/v1beta1/instance/attributes/dartsdk)
export PACKAGE=$(curl http://metadata/computeMetadata/v1beta1/instance/attributes/package)
export VERSION=$(curl http://metadata/computeMetadata/v1beta1/instance/attributes/version)
export MODE=$(curl http://metadata/computeMetadata/v1beta1/instance/attributes/mode)
sudo -E -H -u financeCoding bash -c 'gsutil cp -r gs://dart-carte-du-jour/configurations/github_private_repo_pull ~/ && cd ~/github_private_repo_pull && bash ./clone_project.sh'
sudo -E -H -u financeCoding bash -c 'source /etc/profile && cd ~/github_private_repo_pull/dart-carte-du-jour && pub install && dart bin/package_daemon.dart --verbose --mode $MODE --sdk  $DARTSDK --package $PACKAGE --version $VERSION'
shutdown_instance"""));
    });
  });

  group('gce instance name', () {
    test('scrub instance name', () {
      String packageName = "database_reverse_engineer";
      String gce_name = buildGceName(packageName, "0.0.1");
      print(gce_name);
      print(gce_name.length);
      expect(gce_name, equals("b-databasereverseengi-2b5a2f1b52"));
    });

    test('scrub long instance name', () {
      String packageName = "database_reverse_engineer_baam_baam_waam_package_awesome_balm_wam_slam_jam";

      String gce_name = buildGceName(packageName, "0.0.1");
      print(gce_name);
      print(gce_name.length);
      expect(gce_name, equals("b-databasereverseengi-2b5a2f1b52"));
    });
  });
}
