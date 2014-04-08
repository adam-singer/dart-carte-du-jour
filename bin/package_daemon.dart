import "dart:async";

import 'package:args/args.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

class PubRequestService {
  static const _TIMEOUT = const Duration(seconds: 3);
  Timer _timer;

  PubRequestService() {
  }

  start() {
    _timer = new Timer.periodic(_TIMEOUT, _callback);
  }

  stop() {
    _timer.cancel();
  }

  void _callback(Timer timer) {
    print("callback ${timer.isActive}");
  }
}

void main(args) {
  ArgParser parser = _createArgsParser();
  ArgResults results = parser.parse(args);
  if (results['help']) {
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
    return parser;
}

void _printUsage(ArgParser parser) {
  print('usage: dart bin/package_daemon <options>');
  print('');
  print('where <options> is one or more of:');
  print(parser.getUsage().replaceAll('\n\n', '\n'));
}