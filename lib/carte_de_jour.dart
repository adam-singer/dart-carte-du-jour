library carte_de_jour;

import "dart:io";
import "dart:async";
import "dart:convert";

import "package:path/path.dart";
import 'package:http/http.dart' as http;

final String PACKAGES_DATA_URI = "http://pub.dartlang.org/packages.json";
final String PACKAGE_STORAGE_ROOT = "gs://dartdocs.org/documentation";
final String BUILD_DOCUMENTATION_CACHE = "build_documentation_cache";
final String BUILD_DOCUMENTATION_ROOT_PATH =
"build_documentation_cache/hosted/pub.dartlang.org";
final String DARTDOC_VIEWER_OUT = 'dartdoc-viewer/client/out';


/**
 * Class prepresentation of `<package>.json` file.
 */
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

/**
 * Copy generated documentation package and version to cloud storage.
 */
int copyDocumentation(Package package, String version) {
  String packageFolderPath = "${package.name}-${version}";
  String workingDirectory = join(BUILD_DOCUMENTATION_ROOT_PATH, packageFolderPath,
      DARTDOC_VIEWER_OUT);
  String webPath = 'web';
  String cloudDocumentationPath = join(PACKAGE_STORAGE_ROOT, package.name, version);
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
