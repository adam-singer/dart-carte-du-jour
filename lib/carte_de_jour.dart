library carte_de_jour;

import "dart:io";
import "dart:async";
import "dart:collection";
import "dart:convert";
import "package:meta/meta.dart";
import 'package:http/http.dart' as http;

final String PACKAGES_DATA_URI = "http://pub.dartlang.org/packages.json";
final String PACKAGE_STORAGE_ROOT = "gs://dartdocs-org/documentation";
final String BUILD_DOCUMENTATION_CACHE = "build_documentation_cache";

class Package {
  List<String> uploaders;
  String name;
  List<String> versions;
  Package.fromJson(Map data) {
    uploaders = new List<String>();
    if (data.containsKey('uploaders')) {
      for (var u in data['uploaders']) {
        uploaders.add(u);
      }
    }

    if (data.containsKey('name')) {
      name = data['name'];
    }

    versions = new List<String>();
    if (data.containsKey('versions')) {
      versions.addAll(data['versions'].toList());
    }
  }
}

class PubPackages {
  String prev;
  List<String> packages;
  int pages;
  String next;
  PubPackages.fromJson(Map data) {
    if (data.containsKey('prev')) {
      prev = data['prev'];
    }

    if (data.containsKey('pages')) {
      pages = data['pages'];
    }

    if (data.containsKey('next')) {
      next = data['next'];
    }

    packages = new List<String>();
    if (data.containsKey('packages')) {
      for (var p in data['packages']) {
        packages.add(p);
      }
    }
  }
}

Future<PubPackages> fetchPackages() {
  return http.get(PACKAGES_DATA_URI).then((response) {
      var data = JSON.decode(response.body);
    PubPackages pubPackages = new PubPackages.fromJson(data);
    return pubPackages;
  });
}

Future<Package> fetchPackage(String packageJsonUri) {
  return http.get(packageJsonUri).then((response) {
    var data = JSON.decode(response.body);
    Package package = new Package.fromJson(data);
    return package;
  });
}

@deprecated
String generatePubSpecFile(String packageName, String packageVersion, String mockPackageName) {
  StringBuffer pubSpecData = new StringBuffer()
  ..writeln("name: $mockPackageName")
  ..writeln("dependencies:")
  ..writeln("  $packageName: '$packageVersion'");
  return pubSpecData.toString();
}

String generateStorageLocation(String packageName, String packageVersion) {
  return "${PACKAGE_STORAGE_ROOT}/${packageName}/${packageVersion}";
}

Future<int> buildDocumentationCache(Package package) {
  return Process.run('pub', ['cache', 'add', package.name, '--all'],
  environment: {'PUB_CACHE': BUILD_DOCUMENTATION_CACHE})
  .then((ProcessResult result) {
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    return result.exitCode;
  });
}
