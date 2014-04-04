library carte_de_jour;

import "dart:io";
import "dart:async";
import "dart:collection";
import "dart:convert";
import "package:path/path.dart";
import "package:meta/meta.dart";
import 'package:http/http.dart' as http;

final String PACKAGES_DATA_URI = "http://pub.dartlang.org/packages.json";
final String PACKAGE_STORAGE_ROOT = "gs://dartdocs-org/documentation";
final String BUILD_DOCUMENTATION_CACHE = "build_documentation_cache";
final String BUILD_DOCUMENTATION_ROOT_PATH = BUILD_DOCUMENTATION_CACHE + "/hosted/pub.dartlang.org";

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
  // TODO(adam): make this run sync to avoid out of memory exceptions
  return Process.run('pub', ['cache', 'add', package.name, '--all'],
  environment: {'PUB_CACHE': BUILD_DOCUMENTATION_CACHE})
  .then((ProcessResult result) {
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    return result.exitCode;
  });
}

int buildDocumentationCacheSync(Package package, {Map additionalEnvironment: null}) {
  Map environment = {};
  environment['PUB_CACHE'] = BUILD_DOCUMENTATION_CACHE;
  if (additionalEnvironment != null) {
    environment.addAll(additionalEnvironment);
  }

  ProcessResult processResult = Process.runSync('pub', ['cache', 'add', package.name, '--all'],
  environment: environment, runInShell: true);
  stdout.write(processResult.stdout);
  stderr.write(processResult.stderr);
  return processResult.exitCode;
}

int initPackageVersion(Package package, String version) {
  String path = BUILD_DOCUMENTATION_ROOT_PATH + "/${package.name}-${version}";
  return pubInstall(path);
}

int pubInstall(String workingDirectory) {
  List<String> args = ['install'];
  ProcessResult processResult = Process.runSync('pub', args, workingDirectory: workingDirectory, runInShell: true);
  stdout.write(processResult.stdout);
  stderr.write(processResult.stderr);
  return processResult.exitCode;
}

int buildDocumentationSync(Package package, String version) {
  String outputFolder = 'docs';
  String dartSdkFolder = '/Applications/dart/dart-sdk'; // TODO(adam): get from environment.
  String packagesFolder = './packages'; // The pub installed packages
  String dartFiles = './lib/*.dart'; // TODO(adam): use analyzer to

  List<String> args = ['--compile', '--include-private', '--out', outputFolder,
'--sdk', dartSdkFolder, '--package-root',
packagesFolder, dartFiles];

  String workingDirectory = BUILD_DOCUMENTATION_ROOT_PATH + "/${package.name}-${version}";
  ProcessResult processResult = Process.runSync('docgen', args, workingDirectory: workingDirectory, runInShell: true);
  stdout.write(processResult.stdout);
  stderr.write(processResult.stderr);
  return processResult.exitCode;
}

List<String> findDartLibraryFiles(Package package, String version) {
  RegExp partOf = new RegExp('^part\Wof\W[a-zA-Z]([a-zA-Z0-9_-]*);\$');
  Directory libraryDirectory = new Directory(BUILD_DOCUMENTATION_ROOT_PATH + "/${package.name}-${version}/lib");
  List<FileSystemEntity> libraryFiles = libraryDirectory.listSync(followLinks: false);

  // TODO(adam): chain these together.
  libraryFiles = libraryFiles.where((FileSystemEntity entity) => FileSystemEntity.isFileSync(entity.path)
          && extension(entity.path) == '.dart').toList();
  libraryFiles.removeWhere((FileSystemEntity entity) {
    String libraryFileString = new File(entity.path).readAsStringSync();
    return partOf.hasMatch(libraryFileString);
  });
  return libraryFiles.map((e) => e.path).toList();
}