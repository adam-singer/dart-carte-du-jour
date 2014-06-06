library carte_de_jour;

import "dart:io";
import "dart:async";
import "dart:convert";

import "package:logging/logging.dart";
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

part 'src/global_config.dart';
part 'src/fetch_packages.dart';
part 'src/package.dart';
part 'src/package_build_info.dart';
part 'src/pub_packages.dart';
part 'src/commands_enums.dart';
part 'src/package_build_info_data_store.dart';
part 'src/client_builder_config.dart';
part 'src/google_compute_engine_config.dart';

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
  String externalIpAddress = "none";
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
