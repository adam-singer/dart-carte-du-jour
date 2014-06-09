import "dart:io";
import "dart:convert";

import 'package:args/args.dart';
import 'package:logging/logging.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

void main(args) {
  Logger.root.onRecord.listen((LogRecord record) {
    print(record.message);
  });

  Logger.root.finest("args = ${args}");

  // TODO(adam): move arg parsing and command invoking to `unscripted`
  ArgParser parser = _createArgsParser();
  ArgResults results = parser.parse(args);

  if (results['clientConfig'] != null) {
    // TODO: move to parser callback
    String clientConfig = new File(results['clientConfig']).readAsStringSync();
    var data = JSON.decode(clientConfig);
    ClientBuilderConfig clientBuilderConfig =
        new ClientBuilderConfig.fromJson(data);

    startClient(clientBuilderConfig);
    return;
  } else {
    print("You must provide a value for 'clientConfig'.");
    _printUsage(parser);
  }
}

void startClient(ClientBuilderConfig clientBuilderConfig) {
  clientBuilderConfig.packages.forEach((Package package) {
    package.versions.forEach((Version version) {
      buildVersion(package.name, version, clientBuilderConfig);
    });
  });
}

// TODO(adam): move to carte_de_jour.dart
void buildVersion(String packageName,
                 Version version, ClientBuilderConfig clientBuilderConfig) {
  Logger.root.info("Starting build of ${packageName} ${version}");
  Package package = new Package(packageName, [version]);
  String dartSdk = clientBuilderConfig.sdkPath;

  GoogleComputeEngineConfig googleComputeEngineConfig =
      clientBuilderConfig.googleComputeEngineConfig;
  PackageBuildInfoDataStore packageBuildInfoDataStore
      = new PackageBuildInfoDataStore(googleComputeEngineConfig);

  try {
    package.buildDocumentationCacheSync(versionConstraint: version);
    package.initPackageVersion(version);
    package.buildDocumentationSync(version, dartSdk);
    package.moveDocumentationPackages(version);
    package.copyDocumentation(version);
    // Copy the package_build_info.json file, should only be copied if everything
    // else was successful.
    package.createPackageBuildInfo(version, true);
    package.copyPackageBuildInfo(version);

    // TODO: Factor out into Package class
    // all time stamps need to be in UTC/Iso8601 format.
    var now = new DateTime.now().toUtc().toIso8601String();
    PackageBuildInfo packageBuildInfo =
        new PackageBuildInfo(package.name, version, now, true, buildLogStorePath());
    packageBuildInfoDataStore.save(packageBuildInfo).then((r) {
      Logger.root.info("packageBuildInfoDataStore success:${r}");
    });
  } catch (e) {
    Logger.root.severe(("Not able to build ${package.toString()}"));
    package.createPackageBuildInfo(version, false);
    package.copyPackageBuildInfo(version);

    // TODO: Factor out into Package class
    // all time stamps need to be in UTC/Iso8601 format.
    var now = new DateTime.now().toUtc().toIso8601String();
    PackageBuildInfo packageBuildInfo =
        new PackageBuildInfo(package.name, version, now, false, buildLogStorePath());
    packageBuildInfoDataStore.save(packageBuildInfo).then((r) {
      Logger.root.info("packageBuildInfoDataStore failed:${r}");
    });
  }
}

ArgParser _createArgsParser() {
  ArgParser parser = new ArgParser();
    parser.addFlag('help',
        abbr: 'h',
        negatable: false,
        help: 'show command help',
        callback: (help) {
          if (help) {
            _printUsage(parser);
          }
        });

    parser.addFlag('verbose', abbr: 'v',
        help: 'Output more logging information.', negatable: false,
        callback: (verbose) {
          if (verbose) {
            Logger.root.level = Level.FINEST;
          }
        });

    // TODO(adam): rename option to `--config`
    parser.addOption(
        'clientConfig',
        help: 'Path to the config. Required.',
        defaultsTo: null);

    return parser;
}

void _printUsage(ArgParser parser) {
  print('usage: dart bin/client_builder.dart <options>');
  print('');
  print('where <options> is one or more of:');
  print(parser.getUsage().replaceAll('\n\n', '\n'));
  exit(1);
}
