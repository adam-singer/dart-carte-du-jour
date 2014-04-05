import "dart:io";
import "dart:async";

import 'package:args/args.dart';

// TODO(adam): rename dart-carte-du-jour to dart_carte_du_jour
import 'package:dart-carte-du-jour/carte_de_jour.dart';

void main(args) {
//  fetchPackages().then((PubPackages pubPackages) {
//    return pubPackages.packages.map(fetchPackage).toList();
//  }).then((List<Future<Package>> packages) {
//    return Future.wait(packages);
//  }).then((List<Package> packages) {
//    packages.forEach((e) => print("name: ${e.name}"));
//    return packages.map(buildDocumentationCache).toList();
//  }).then((List<Future<int>> cacheResults) {
//    return Future.wait(cacheResults);
//  }).then((List<int> results) {
//    print("results = ${results}");
//  });

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