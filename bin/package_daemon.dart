import "dart:async";

import 'package:args/args.dart';
import 'package:logging/logging.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

class PubRequestService {
  Duration _timeout;
  Timer _timer;

  PubRequestService({int seconds: 3}) {
    _timeout = new Duration(seconds: seconds);
  }

  start() {
    _timer = new Timer.periodic(_timeout, _callback);
  }

  stop() {
    _timer.cancel();
  }

  void _callback(Timer timer) {
    Logger.root.fine("callback ${timer.isActive}");
    fetchPackages().then((PubPackages pubPackages) {
      return pubPackages.packages.map(fetchPackage).toList();
    }).then((List<Future<Package>> packages) {
      return Future.wait(packages);
    }).then((List<Package> packages) {
      Logger.root.fine("All packages fetched");
      // TODO: implement a package checker for cloud storage.

      // As of now we should only check the latest version of the packages.
      packages.forEach((Package p) {
        p.versions = [p.versions.last];
      });


    });
  }
}

void main(args) {
  // TODO(adam): move arg parsing and command invoking to `unscripted`
  ArgParser parser = _createArgsParser();
  ArgResults results = parser.parse(args);
  if (results['help'] || results.rest.length == 0) {
    _printUsage(parser);
    return;
  }

  String dartSdk;
  if (results['sdk'] == null) {
    print("You must provide a value for 'sdk'.");
    _printUsage(parser);
    return;
  } else {
    dartSdk = results['sdk'];
  }


  if (results['daemon'] != null && results['client'] != null) {
    print("You must choose `daemon` or `client` modes to run in. Cannot choose both.");
    _printUsage(parser);
    return;
  }

  Logger.root.onRecord.listen((LogRecord record) {
    print(record.message);
  });


  if (results['client']) {
    print("Running in client mode");
    String package = results['package'];
    String version = results['version'];
    _initClient(dartSdk, package, version);
    return;
  }

  if (results['daemon']) {
    print("Running in daemon mode");
    String sleepInterval = results['sleepinterval'];
    String maxClients = results['maxclients'];
    _initDaemon(sleepInterval, maxClients);
    return;
  }

  return;
}

void _initClient(String dartSdk, String packageName, String version) {
  Logger.root.info("Starting build of ${packageName} ${version}");
  Package package = new Package(packageName, [version]);
  buildDocumentationCacheSync(package);
  initPackageVersion(package, version);
  buildDocumentationSync(package, version, dartSdk);
  moveDocumentationPackages(package, version);
  copyDocumentation(package, version);
}

// TODO: remove
_oldCodeRemove(String dartSdk) {
  // TODO(adam): remove the fetching of packages.
  fetchPackages().then((PubPackages pubPackages) {
      return pubPackages.packages.map(fetchPackage).toList();
    }).then((List<Future<Package>> packages) {
      return Future.wait(packages);
    }).then((List<Package> packages) {
      // TESTING
      print("removing packages for testing");
      packages = packages.getRange(0,1).toList();
      packages.forEach((Package p) {
        p.versions = [p.versions.last];
      });

      packages.forEach((e) => print("name: ${e.name}, versions: ${e.versions}"));

      for (var p in packages) {
        buildDocumentationCacheSync(p);
      }

      for (var p in packages) {
        initPackageVersion(p, p.versions[0]);
      }

      for (var p in packages) {
        buildDocumentationSync(p, p.versions[0], dartSdk);
        moveDocumentationPackages(p, p.versions[0]);
      }

      for (var p in packages) {
        copyDocumentation(p, p.versions[0]);
      }

      return packages;
    });
}

void _initDaemon(String sleepInterval, String maxClients) {
  PubRequestService pubRequestService = new PubRequestService();
  pubRequestService.start();
}

_createArgsParser() {
  ArgParser parser = new ArgParser();
    parser.addFlag('help',
        abbr: 'h',
        negatable: false,
        help: 'show command help');
    parser.addOption(
        'sdk',
        abbr: 's',
        help: 'Path to the sdk. Required.');

    // Should be run in one of two modes
    //
    // Daemon mode is the process where we scan for new packages and check
    // status of compute engine instances.
    //
    // Client mode is where we generate the actual documentation packages
    // and publish them to pub.dartlang.org.
    parser.addFlag(
        'daemon',
        abbr: 'd',
        help: 'run in daemon mode');
    parser.addFlag(
        'client',
        abbr: 'c',
        help: 'run in client mode');

    //
    // Daemon options
    //
    parser.addOption(
        'sleepinterval',
        abbr: 'i',
        help: 'Time requred to sleep in seconds before polling for new packages on pub.dartlang.org');
    parser.addOption(
        'maxclients',
        abbr: 'q',
        help: 'Max number of possible client instances to fire up.');

    //
    // Client options
    //
    parser.addOption(
        'package',
        abbr: 'p',
        help: 'Package to generate documentation for.');
    parser.addOption( // TODO(adam): support possible version constraints for package generation.
        'version',
        abbr: 'v',
        help: 'Version of package to generate.');
    return parser;
}

void _printUsage(ArgParser parser) {
  print('usage: dart bin/package_daemon <options>');
  print('');
  print('where <options> is one or more of:');
  print(parser.getUsage().replaceAll('\n\n', '\n'));
}