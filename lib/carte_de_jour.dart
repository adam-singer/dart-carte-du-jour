library carte_de_jour;

import "dart:io";
import "dart:async";
import "dart:convert";

import "package:logging/logging.dart";
import "package:crypto/crypto.dart";
import "package:path/path.dart";
import 'package:http/http.dart' as http;

final String PACKAGES_DATA_URI = "http://pub.dartlang.org/packages.json";
final String PACKAGE_STORAGE_ROOT = "gs://dartdocs.org/documentation";
final String DOCUMENTATION_HTTP_ROOT = "http://storage.googleapis.com/dartdocs.org/documentation";

final String DARTDOC_VIEWER_OUT = 'dartdoc-viewer/client/out';

// TODO(adam): create a class object that has these as members.
String BUILD_DOCUMENTATION_CACHE = "/tmp/build_documentation_cache";
String BUILD_DOCUMENTATION_ROOT_PATH =
"/tmp/build_documentation_cache/hosted/pub.dartlang.org";

/**
 * Class prepresentation of `<package>.json` file.
 */
class Package {
  List<String> uploaders;
  String name;
  List<String> versions;

  Package(this.name, this.versions, {this.uploaders});

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

/**
 * Class prepresentation of `packages.json` file.
 */
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

/**
 * Class representation of BUILD_VERSION file.
 */
class PackageBuildInfo {
  String name;
  String version;
  String datetime;
  bool isBuilt;

  PackageBuildInfo(this.name, this.version, this.datetime, bool isBuilt);

  PackageBuildInfo.fromJson(Map data) {
    if (data.containsKey("name")) {
      name = data["name"];
    }

    if (data.containsKey("version")) {
      version = data["version"];
    }

    if (data.containsKey("datetime")) {
      datetime = data["datetime"];
    }

    if (data.containsKey("isBuilt")) {
      // TODO(adam): if we decoded from json, this might not be needed... should be a type by then.
      isBuilt = data['isBuilt'].toString().toLower() == 'true' ? true : false;
    }
  }

  String toString() {
    Map data = new Map<String, String>();
    data["name"] = name;
    data["version"] = version;
    data["datetime"] = datetime;
    data["isBuilt"] = isBuilt;
    return JSON.encode(data);
  }
}

/**
 * Fetch packages.json file and return PubPackages
 */
Future<PubPackages> fetchPackages([String page]) {
  // TODO(adam): implement `page` so any page could be fetched.
  return http.get(PACKAGES_DATA_URI).then((response) {
    var data = JSON.decode(response.body);
    PubPackages pubPackages = new PubPackages.fromJson(data);
    return pubPackages;
  });
}

/**
 * Fetch a particular `<package>.json` file and return `Package`
 */
Future<Package> fetchPackage(String packageJsonUri) {
  return http.get(packageJsonUri).then((response) {
    var data = JSON.decode(response.body);
    Package package = new Package.fromJson(data);
    return package;
  });
}

@deprecated
String generatePubSpecFile(String packageName, String packageVersion, String
    mockPackageName) {
  StringBuffer pubSpecData = new StringBuffer()
      ..writeln("name: $mockPackageName")
      ..writeln("dependencies:")
      ..writeln("  $packageName: '$packageVersion'");
  return pubSpecData.toString();
}

@deprecated
String generateStorageLocation(String packageName, String packageVersion) {
  return "${PACKAGE_STORAGE_ROOT}/${packageName}/${packageVersion}";
}

@deprecated
Future<int> buildDocumentationCache(Package package) {
  // TODO(adam): make this run sync to avoid out of memory exceptions
  return Process.run('pub', ['cache', 'add', package.name, '--all'],
      environment: {
    'PUB_CACHE': BUILD_DOCUMENTATION_CACHE
  }).then((ProcessResult result) {
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    return result.exitCode;
  });
}

/**
 * Builds the cache for a package.
 */
int buildDocumentationCacheSync(Package package, {Map additionalEnvironment:
    null}) {
  // TODO(adam): add version constraint parameter.
  Map environment = {};
  environment['PUB_CACHE'] = BUILD_DOCUMENTATION_CACHE;
  if (additionalEnvironment != null) {
    environment.addAll(additionalEnvironment);
  }

  ProcessResult processResult = Process.runSync('pub', ['cache', 'add',
      package.name, '--all'], environment: environment, runInShell: true);
  stdout.write(processResult.stdout);
  stderr.write(processResult.stderr);
  return processResult.exitCode;
}

/**
 * Bootstrap a version of a package.
 */
int initPackageVersion(Package package, String version) {
  String path = join(BUILD_DOCUMENTATION_ROOT_PATH,
      "${package.name}-${version}");
  return pubInstall(path);
}

/**
 * Execute `pub install` at the `workingDirectory`
 */
int pubInstall(String workingDirectory) {
  List<String> args = ['install'];
  ProcessResult processResult = Process.runSync('pub', args, workingDirectory:
      workingDirectory, runInShell: true);
  stdout.write(processResult.stdout);
  stderr.write(processResult.stderr);
  return processResult.exitCode;
}

_buildCloudStorageDocumentationPath(Package package, String version) {
  return join(PACKAGE_STORAGE_ROOT, package.name, version);
}

_buildHttpDocumentationPath(Package package, String version) {
  return join(DOCUMENTATION_HTTP_ROOT, package.name, version);
}

/**
 * Copy generated documentation package and version to cloud storage.
 */
int copyDocumentation(Package package, String version) {
  String packageFolderPath = "${package.name}-${version}";
  String workingDirectory = join(BUILD_DOCUMENTATION_ROOT_PATH, packageFolderPath,
      DARTDOC_VIEWER_OUT);
  String webPath = 'web';
  String cloudDocumentationPath = _buildCloudStorageDocumentationPath(package, version);
  List<String> args = ['cp', '-e', '-c', '-a', 'public-read', '-r', webPath,
                       cloudDocumentationPath];

  ProcessResult processResult = Process.runSync('gsutil', args, workingDirectory:
      workingDirectory, runInShell: true);
  stdout.write(processResult.stdout);
  stderr.write(processResult.stderr);
  return processResult.exitCode;
}

/**
 * Moves the packages folder into the root of the web folder. WARNING: this may
 * change in the future versions dartdoc-viewer.
 *
 */
void moveDocumentationPackages(Package package, String version) {
  String out = join(BUILD_DOCUMENTATION_ROOT_PATH, "${package.name}-${version}",
      DARTDOC_VIEWER_OUT);
  String webPath = join(out, 'web');
  String webPackagesPath = join(webPath, 'packages');
  String outPackagesPath = join(out, 'packages');

  // 1) remove symlink in out/web/packages
  Directory webPackagesDirectory = new Directory(webPackagesPath);
  webPackagesDirectory.deleteSync();

  // 2) move out/packages to out/web/packages
  Directory outPackagesDirectory = new Directory(outPackagesPath);
  outPackagesDirectory.renameSync(webPackagesPath);
}

/**
 * Builds documentation for a particular version of a package.
 */
int buildDocumentationSync(Package package, String version, String dartSdkPath) {
  String outputFolder = 'docs';
  String packagesFolder = './packages'; // The pub installed packages
  String workingDirectory = join(BUILD_DOCUMENTATION_ROOT_PATH,
      "${package.name}-${version}");
  List<String> dartFiles = findDartLibraryFiles(join(workingDirectory, "lib"));
  dartFiles =
      dartFiles.map((e) => basename(e)).map((e) => join("lib", e)).toList();
  List<String> args = ['--compile', '--no-include-sdk', '--include-private',
                       '--out', outputFolder, '--sdk', dartSdkPath,
                       '--package-root', packagesFolder];
  args.addAll(dartFiles);

  print("workingDirectory = ${workingDirectory}");
  print("docgen ${args}");

  ProcessResult processResult = Process.runSync('docgen', args,
      workingDirectory: workingDirectory, runInShell: true);
  stdout.write(processResult.stdout);
  stderr.write(processResult.stderr);
  Logger.root.fine("docgen exit code = ${processResult.exitCode}");
  return processResult.exitCode;
}

/**
 * Finds all possible dart library files by excluding `.dart` files that have
 * a `part of id;` string.
 */
List<String> findDartLibraryFiles(String libPath) {
  RegExp partOf = new RegExp(r'^part\Wof\W[a-zA-Z]([a-zA-Z0-9_-]*);$');
  Directory libraryDirectory = new Directory(libPath);
  if (!libraryDirectory.existsSync()) {
    return [];
  }

  List<FileSystemEntity> libraryFiles = libraryDirectory.listSync(followLinks:
      false).where((FileSystemEntity entity) => FileSystemEntity.isFileSync(
          entity.path) && extension(entity.path) == '.dart').toList();

  libraryFiles.removeWhere((FileSystemEntity entity) {
        List<String> libraryFileString = new File(entity.path).readAsLinesSync();
        String m = libraryFileString.firstWhere((e) => partOf.hasMatch(e), orElse: () => "");
        return m.isNotEmpty;
      });
  return libraryFiles.map((e) => e.path).toList();
}

// Build a startup script
String buildStartupScript() {
  // TODO(adam): add mustash templates
  return "";
}

String versionHash(String version) {
  SHA1 versionHash = new SHA1()
  ..add(version.codeUnits);
  return versionHash.close().map((e) => e.toRadixString(16)).take(5).toList().join();
}
// Call gcutil to deploy a node
deployDocumentationBuilder(Package package, String version) {
  String service_version = "v1";
  String project = "dart-carte-du-jour";
  String instanceName = "b-${package.name}-${versionHash(version)}";
  String zone = "us-central1-a";
  String machineType = "f1-micro";
  String network = "default"; // TODO(adam): we should use the internal network
  String externalIpAddress = "ephemeral";
  String serviceAccountScopes = "https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.full_control";
  String image = "https://www.googleapis.com/compute/v1/projects/dart-carte-du-jour/global/images/dart-engine-v1"; // TODO(adam): parameterize this
  String persistentBootDisk = "true";
  String autoDeleteBootDisk = "true";
  String startupScript = "startup-script.sh"; // TODO(adam): dont actually write a startup-script.sh to file system, pass it as a string if possible
  String metadataFromFile = "startup-script:$startupScript";

  String workingDirectory = "/tmp/"; // TODO(adam): this might need to be the location where the startup-script.sh was generated..
  String metadataPackageName = package.name;
  String metadataPackageVersion = version;

  List<String> args = ['--service_version="$service_version"',
                       '--project="$project"',
                       'addinstance',
                       instanceName,
                       '--zone="$zone"',
                       '--machine_type="$machineType"',
                       '--network="$network"',
                       '--external_ip_address="$externalIpAddress"',
                       '--service_account_scopes="$serviceAccountScopes"',
                       '--image="$image"',
                       '--persistent_boot_disk="$persistentBootDisk"',
                       '--auto_delete_boot_disk="$autoDeleteBootDisk"',
                       '--metadata="$metadataPackageName"',
                       '--metadata="$metadataPackageVersion"',
                       '--metadata_from_file=$metadataFromFile'];
  ProcessResult processResult = Process.runSync('gcutil', args,
      workingDirectory: workingDirectory, runInShell: true);
  stdout.write(processResult.stdout);
  stderr.write(processResult.stderr);
  return processResult.exitCode;

//  gcutil --service_version="v1"
//  --project="dart-carte-du-jour"
//  addinstance "test-instance"
//  --zone="us-central1-a"
//  --machine_type="g1-small"
//  --network="default"
//  --external_ip_address="ephemeral"
//  --service_account_scopes="https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.full_control"
//  --image="https://www.googleapis.com/compute/v1/projects/dart-carte-du-jour/global/images/dart-engine-v1"
//  --persistent_boot_disk="true"
//  --auto_delete_boot_disk="true"
//  --metadata_from_file=startup-script:$STARTUP_SCRIPT
}

Future<PackageBuildInfo> checkPackageIsBuilt(Package package, String version) {
  String docPath = _buildHttpDocumentationPath(package, version);
  // TODO: response / error handling.
  return http.get(docPath).then((response) {
    var data = JSON.decode(response.body);
    PackageBuildInfo packageBuildInfo = new PackageBuildInfo.fromJson(data);
    return packageBuildInfo;
  });
}
