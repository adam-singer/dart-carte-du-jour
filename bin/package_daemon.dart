import "dart:async";
import "dart:io";

import 'package:args/args.dart';
import 'package:logging/logging.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

class PubRequestService {
  Duration _timeout;
  Timer _timer;

  PubRequestService({int seconds: 1800}) {
    _timeout = new Duration(seconds: seconds);
  }

  start() {
    _timer = new Timer.periodic(_timeout, callback);
  }

  stop() {
    _timer.cancel();
  }

  void callback(Timer timer) {
    Logger.root.fine("fetching pub packages");
    fetchPackages().then((PubPackages pubPackages) {
      Logger.root.fine("pub packages fetched");
      return pubPackages.packages.map(fetchPackage).toList();
    }).then((List<Future<Package>> packages) {
      Logger.root.fine("Waiting for individual packages to be fetched");
      return Future.wait(packages);
    }).then((List<Package> packages) {
      Logger.root.fine("All packages fetched");

      // As of now we should only check the latest version of the packages.
      Logger.root.warning("Only checking for the latest version of built packages");
      packages.forEach((Package p) {
        p.versions = [p.versions.last];
      });

      return packages.map((p) => checkPackageIsBuilt(p, p.versions.last)).toList();
    }).then((List<Future<PackageBuildInfo>> packageBuildInfos){
      return Future.wait(packageBuildInfos);
    }).then((List<PackageBuildInfo> packageBuildInfos) {
      // TODO: refactor the model objects so its easy to map which package and what version of that
      // package is built or not built.

      packageBuildInfos.forEach((PackageBuildInfo p) {
        Logger.root.fine("p = ${p.toString()}");
      });

      // Filter out the packages that are not built
      packageBuildInfos = packageBuildInfos.where((PackageBuildInfo p) => p.isBuilt == false).toList();

      // TODO: queue packages instead of just taking the first 10
      packageBuildInfos = packageBuildInfos.take(10).toList();

      Logger.root.fine("Building following packages: ${packageBuildInfos}");

      packageBuildInfos.forEach((PackageBuildInfo p) {
        Package package = new Package(p.name, [p.version]);
        deployDocumentationBuilder(package, p.version);
      });
    });
  }
}

void main(args) {
  Logger.root.onRecord.listen((LogRecord record) {
    print(record.message);
  });

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
    print("Running in daemon mode");
    String sleepInterval = results['sleep-interval'];
    String maxClients = results['max-clients'];
    _initDaemon(sleepInterval, maxClients);
    return;
  }

}

void _initClient(String dartSdk, String packageName, String version) {
  Logger.root.info("Starting build of ${packageName} ${version}");
  Package package = new Package(packageName, [version]);
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
}

void _initDaemon(String sleepInterval, String maxClients) {
  PubRequestService pubRequestService = new PubRequestService();
  // pubRequestService.start();
  pubRequestService.callback(null);
}

_createArgsParser() {
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
    // Daemon mode is the process where we scan for new packages and check
    // status of compute engine instances.
    //
    // Client mode is where we generate the actual documentation packages
    // and publish them to pub.dartlang.org.
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
    // Daemon options
    //
    parser.addOption(
        'sleep-interval',
        help: 'Time requred to sleep in seconds before polling for new packages on pub.dartlang.org',
        defaultsTo: null);
    parser.addOption(
        'max-clients',
        help: 'Max number of possible client instances to fire up.',
        defaultsTo: null);

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
  print('usage: dart bin/package_daemon <options>');
  print('');
  print('where <options> is one or more of:');
  print(parser.getUsage().replaceAll('\n\n', '\n'));
  exit(1);
}