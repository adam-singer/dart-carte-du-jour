import "dart:io";

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

  if (results['mode'] == 'client') {
    String dartSdk;
    if (results['sdk'] == null) {
      print("You must provide a value for 'sdk'.");
      _printUsage(parser);
      return;
    } else {
      dartSdk = results['sdk'];
    }

    print("Running in client mode");
    String package = results['package'];
    String version = results['version'];
    _initClient(dartSdk, package, version);
    return;
  }

  if (results['mode'] == 'daemon') {
    throw new UnsupportedError("daemon mode has been removed.");
  }
}

void _initClient(String dartSdk, String packageName, String version) {
  Logger.root.info("Starting build of ${packageName} ${version}");
  Package package = new Package(packageName, [version]);
  try {
    buildDocumentationCacheSync(package, versionConstraint: version);
    initPackageVersion(package, version);
    buildDocumentationSync(package, version, dartSdk);
    moveDocumentationPackages(package, version);
    copyDocumentation(package, version);
    createVersionFile(package, version);
    copyVersionFile(package, version);
    // Copy the package_build_info.json file, should only be copied if everything
    // else was successful.
    createPackageBuildInfo(package, version, true);
    copyPackageBuildInfo(package, version);
  } catch (e) {
    Logger.root.severe(("Not able to build ${package.toString()}"));
    createPackageBuildInfo(package, version, false);
    copyPackageBuildInfo(package, version);
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

    parser.addOption(
        'sdk',
        help: 'Path to the sdk. Required.',
        defaultsTo: null);

    //
    // Client mode is where we generate the actual documentation packages
    // and publish them to pub.dartlang.org.
    //
    parser.addOption(
        'mode',
        help: 'Path to the sdk. Required.',
        allowed: ['client', 'daemon'],
        allowedHelp: {
          'client': 'run in client mode',
          'daemon': 'run in daemon mode'
        },
        callback: (mode){
          if (mode != "client" && mode != "daemon") {
            print("You must choose `daemon` a `client` mode to run in.");
            _printUsage(parser);
          }
        });

    //
    // Client options
    //
    parser.addOption(
        'package',
        help: 'Package to generate documentation for.', defaultsTo: null);
    parser.addOption( // TODO(adam): support possible version constraints for package generation.
        'version',
        help: 'Version of package to generate.', defaultsTo: null);

    return parser;
}

void _printUsage(ArgParser parser) {
  print('usage: dart bin/client_builder.dart <options>');
  print('');
  print('where <options> is one or more of:');
  print(parser.getUsage().replaceAll('\n\n', '\n'));
  exit(1);
}