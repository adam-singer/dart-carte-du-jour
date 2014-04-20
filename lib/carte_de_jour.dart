library carte_de_jour;

import "dart:io";
import "dart:async";
import "dart:convert";

import "package:logging/logging.dart";
import "package:crypto/crypto.dart";
import "package:path/path.dart";
import 'package:http/http.dart' as http;
import 'package:mustache/mustache.dart' as mustache;

part 'src/package.dart';
part 'src/package_build_info.dart';
part 'src/pub_packages.dart';
part 'src/commands_enums.dart';

final String PACKAGES_DATA_URI = "http://pub.dartlang.org/packages.json";
final String PACKAGE_STORAGE_ROOT = "gs://www.dartdocs.org/documentation";
final String DOCUMENTATION_HTTP_ROOT = "http://storage.googleapis.com/www.dartdocs.org/documentation";
final String DARTDOC_VIEWER_OUT = 'dartdoc-viewer/client/out';
final String PACKAGE_BUILD_INFO_FILE_NAME = "package_build_info.json";

// TODO(adam): create a class object that has these as members.
final String BUILD_DOCUMENTATION_CACHE = "/tmp/build_documentation_cache";
final String BUILD_DOCUMENTATION_ROOT_PATH =
"/tmp/build_documentation_cache/hosted/pub.dartlang.org";

/**
 * Fetch packages.json file and return PubPackages
 */
Future<PubPackages> fetchPackages([int page]) {
  String uri = PACKAGES_DATA_URI + (page != null ? "?page=${page}":"");
  return http.get(uri).then((response) {
    if (response.statusCode != 200) {
      Logger.root.warning("Not able to fetch packages: ${response.statusCode}:${response.body}");
      return null;
    }

    var data = JSON.decode(response.body);
    PubPackages pubPackages = new PubPackages.fromJson(data);
    return pubPackages;
  });
}

/**
 * Fetch all pages of packages.json file and return as `List` of
 * `PubPackages` objects.
 */
Future<List<PubPackages>> fetchAllPackages() {
  Completer completer = new Completer();
  List pubPackages = [];
  int pageCount = 1;

  void callback() {
    fetchPackages(pageCount).then((PubPackages p) {
      Logger.root.finest("pageCount = ${pageCount}");
      if (p.packages.length == 0) {
        completer.complete(pubPackages);
        return;
      }

      pageCount++;
      pubPackages.add(p);
      Timer.run(callback);
    });
  }

  Timer.run(callback);
  return completer.future;
}

/**
 * Fetch a particular `<package>.json` file and return `Package`
 */
Future<Package> fetchPackage(String packageJsonUri) {
  return http.get(packageJsonUri).then((response) {
    if (response.statusCode != 200) {
      Logger.root.warning("Not able to fetch packages: ${response.statusCode}:${response.body}");
      return null;
    }

    var data = JSON.decode(response.body);
    Package package = new Package.fromJson(data);
    return package;
  });
}

/**
 * Fetches all the packages and puts them into `Package` objects
 */
Future<List<Package>> fetchAllPackage() {
  return fetchAllPackages().then((List<PubPackages> pubPackages) {
   Completer completer = new Completer();
   List<String> packagesUris = new List<String>();
   pubPackages.forEach((PubPackages pubPackages) =>
       packagesUris.addAll(pubPackages.packages));

   List<Package> packages = new List<Package>();
   void callback() {
     if (packagesUris.isEmpty) {
       completer.complete(packages);
       return;
     }

     print("fetching ${packagesUris.last}");
     fetchPackage(packagesUris.removeLast()).then((Package package) {
       packages.add(package);
       Timer.run(callback);
     });
   }

   Timer.run(callback);
   return completer.future;
  });
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

String _buildCloudStorageDocumentationPath(Package package, String version) {
  return join(PACKAGE_STORAGE_ROOT, package.name, version);
}

String _buildHttpDocumentationPath(Package package, String version) {
  return join(DOCUMENTATION_HTTP_ROOT, package.name, version, PACKAGE_BUILD_INFO_FILE_NAME);
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
// TODO(adam): make username and application entry parameters
String buildStartupScript(String startupScriptTemplatePath) {
  String startupScriptTemplate =
      new File(startupScriptTemplatePath).readAsStringSync();
  var template = mustache.parse(startupScriptTemplate);
  var startupScript = template.renderString({
    'user_name': 'financeCoding',
    'dart_application': r'bin/client_builder.dart --verbose --mode $MODE --sdk  $DARTSDK --package $PACKAGE --version $VERSION'
  }, htmlEscapeValues: false);
  return startupScript;
}

String versionHash(String version) {
  SHA1 versionHash = new SHA1()
  ..add(version.codeUnits);
  return versionHash.close().map((e) => e.toRadixString(16)).take(5).toList().join();
}

String buildGceName(String packageName, String version) {

  RegExp invalidChars = new RegExp("[^-a-z0-9]");
  RegExp validString = new RegExp("[a-z]([-a-z0-9]{0,61}[a-z0-9])?");
  String prefix = "b-";
  String postfix = "-${versionHash(version)}";

  packageName = packageName.replaceAll(invalidChars, "");
  int packageNameMaxLength = 32 - (prefix.length + postfix.length);
  if (packageName.length > packageNameMaxLength) {
    packageName = packageName.substring(0, packageNameMaxLength);
  }

  String gce_name = prefix+packageName+postfix;
  return gce_name;
}
