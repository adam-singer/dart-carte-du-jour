library carte_de_jour;

import "dart:io";
import "dart:async";
import "dart:convert";

import "package:logging/logging.dart";
import "package:crypto/crypto.dart";
import "package:path/path.dart";
import 'package:http/http.dart' as http;
import 'package:mustache/mustache.dart' as mustache;
import "package:google_oauth2_client/google_oauth2_console.dart";
import "package:google_datastore_v1beta2_api/datastore_v1beta2_api_client.dart"
    as client;
import "package:google_datastore_v1beta2_api/datastore_v1beta2_api_console.dart"
    as console;
import 'package:uuid/uuid_server.dart';

import 'src/version.dart' show Version, VersionConstraint, VersionRange;
export 'src/version.dart' show Version, VersionConstraint, VersionRange;

part 'src/package.dart';
part 'src/package_build_info.dart';
part 'src/pub_packages.dart';
part 'src/commands_enums.dart';
part 'src/package_build_info_data_store.dart';
part 'src/client_builder_config.dart';
part 'src/google_compute_engine_config.dart';

final String PACKAGES_DATA_URI = "http://pub.dartlang.org/packages.json";
final String PACKAGE_STORAGE_ROOT = "gs://www.dartdocs.org/documentation";
final String DOCUMENTATION_HTTP_ROOT = "http://storage.googleapis.com/www.dartdocs.org/documentation";
final String DARTDOC_VIEWER_OUT = 'dartdoc-viewer/client/out';
final String PACKAGE_BUILD_INFO_FILE_NAME = "package_build_info.json";

// TODO(adam): create a class object that has these as members.
final String BUILD_DOCUMENTATION_CACHE = "/tmp/build_documentation_cache";
final String BUILD_DOCUMENTATION_ROOT_PATH =
"/tmp/build_documentation_cache/hosted/pub.dartlang.org";

final String BUILD_LOGS_ROOT = "gs://www.dartdocs.org/buildlogs/";
final String CLIENT_BUILDER_CONFIG_FILES_ROOT = "gs://dart-carte-du-jour/client_builder_configurations/";

final Uuid uuid_generator = new Uuid();

final String CACHE_CONTROL = "Cache-Control:public,max-age=3600";
final String COMPRESS_FILE_TYPES = "json,css,html,xml,js,dart,map,txt";

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
  Logger.root.finest(processResult.stdout);
  Logger.root.severe(processResult.stderr);
  return processResult.exitCode;
}

String _buildCloudStorageDocumentationPath(Package package, Version version) {
  return join(PACKAGE_STORAGE_ROOT, package.name, version.toString());
}

String _buildHttpDocumentationPath(Package package, Version version) {
  return join(DOCUMENTATION_HTTP_ROOT, package.name, version.toString(), PACKAGE_BUILD_INFO_FILE_NAME);
}

/**
 * Finds all possible dart library files by excluding `.dart` files that have
 * a `part of id;` string.
 */
@deprecated
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
    'dart_application': r'bin/client_builder.dart --verbose --sdk  $DARTSDK --config bin/config.json --package $PACKAGE --version $VERSION'
  }, htmlEscapeValues: false);
  return startupScript;
}

String versionHash(Version version) {
  SHA1 versionHash = new SHA1()
  ..add(version.toString().codeUnits);
  return versionHash.close().map((e) => e.toRadixString(16)).take(5).toList().join();
}

@deprecated
String buildGceName(String packageName, Version version) {

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

String buildLogStorePath() {
  return join(BUILD_LOGS_ROOT, "${Platform.localHostname}-startupscript.log");
}

// Build a startup script
// TODO(adam): make username and application entry parameters
String buildMultiStartupScript(String startupScriptTemplatePath, String clientConfigFile) {
  String startupScriptTemplate =
     new File(startupScriptTemplatePath).readAsStringSync();
  var template = mustache.parse(startupScriptTemplate);
  var startupScript = template.renderString({
   'user_name': 'financeCoding',
   'dart_application': r'bin/client_builder.dart --verbose --clientConfig bin/'+clientConfigFile,
   'client_config_file': clientConfigFile
  }, htmlEscapeValues: false);
  return startupScript;
}

// Call gcutil to deploy a node
int deployMultiDocumentationBuilder(ClientBuilderConfig clientBuilderConfig) {
  String service_version = "v1";
  String project = "dart-carte-du-jour";
  String instanceName = clientBuilderConfig.id;
  String zone = "us-central1-a";
  String machineType = "n1-standard-1"; // "g1-small";
  String network = "default"; // TODO(adam): we should use the internal network
  String externalIpAddress = "ephemeral";
  String serviceAccountScopes = "https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.full_control";
  String image = "https://www.googleapis.com/compute/v1/projects/dart-carte-du-jour/global/images/dart-engine-v1"; // TODO(adam): parameterize this
  String persistentBootDisk = "true";
  String autoDeleteBootDisk = "true";
  String startupScript = buildMultiStartupScript("packages/dart_carte_du_jour/multi_package_startup_script.mustache", clientBuilderConfig.storeFileName()); // "startup-script.sh"; // TODO(adam): dont actually write a startup-script.sh to file system, pass it as a string if possible
  String metadataStartupScript = "startup-script:$startupScript";

  String workingDirectory = "/tmp/"; // TODO(adam): this might need to be the location where the startup-script.sh was generated..
  String metadataAutoShutdown = "autoshutdown:1";

  List<String> args = ['--format',
                       'json',
                       '--service_version=$service_version',
                       '--project=$project',
                       'addinstance',
                       instanceName,
                       '--zone=$zone',
                       '--machine_type=$machineType',
                       '--network=$network',
                       '--external_ip_address=$externalIpAddress',
                       '--service_account_scopes=$serviceAccountScopes',
                       '--image=$image',
                       '--persistent_boot_disk=$persistentBootDisk',
                       '--auto_delete_boot_disk=$autoDeleteBootDisk',
                       '--metadata=$metadataAutoShutdown',
                       '--metadata=$metadataStartupScript'];

  Logger.root.finest("gcutil ${args}");

  ProcessResult processResult = Process.runSync('gcutil', args,
      workingDirectory: workingDirectory, runInShell: true);
  Logger.root.finest(processResult.stdout);
  Logger.root.severe(processResult.stderr);

  return processResult.exitCode;
}

bool multiDocumentationInstanceAlive(ClientBuilderConfig clientBuilderConfig) {
  String service_version = "v1";
  String project = "dart-carte-du-jour";
  String instanceName = clientBuilderConfig.id;
  String zone = "us-central1-a";

  // TODO: Use the dart client apis
  // https://developers.google.com/compute/docs/instances#checkmachinestatus
  List<String> args = ['--format',
                       'json',
                       '--service_version=$service_version',
                       '--project=$project',
                       'getinstance',
                       instanceName,
                       '--zone=$zone'];

  Logger.root.finest("gcutil ${args}");

  ProcessResult processResult = Process.runSync('gcutil', args, runInShell: true);
  // TODO: read stdout into json object and check status
  Logger.root.finest(processResult.stdout);
  // To much stderr printed out
  // Logger.root.severe(processResult.stderr);

  if (processResult.exitCode == 0) {
    return true;
  } else {
    return false;
  }
}
