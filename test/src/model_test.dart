library test_model;

import 'dart:convert';

import 'package:test/test.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

void testPackage() {
  group('Package', () {
    test('fromJson', () {
      String unittestPackageModel = """
      {
    "name": "unittest",
    "uploaders": [
        "dgrove@google.com",
        "jmesserly@google.com"
    ],
    "versions": [
        "0.10.0",
        "0.10.1",
        "0.10.1+1"
    ]
}""";
      Package package = new Package.fromJson(JSON.decode(unittestPackageModel));
      expect(package.name, equals("unittest"));
      expect(package.versions.length, equals(3));
      expect(package.versions.contains(new Version.parse('0.10.0')), isTrue);
      expect(package.uploaders.length, equals(2));
      expect(package.uploaders.contains('dgrove@google.com'), isTrue);

    });

  });
}

void testPubPackages() {
  group('PubPackages', () {
    test('fromJson', () {
      String packages = """
      {
    "next": "http://pub.dartlang.org/packages.json?page=2",
    "packages": [
        "http://pub.dartlang.org/packages/tags.json",
        "http://pub.dartlang.org/packages/smartcanvas.json",
        "http://pub.dartlang.org/packages/annotation_crawler.json"
    ],
    "pages": 15,
    "prev": null
}
      """;
      PubPackages pubPackages = new PubPackages.fromJson(JSON.decode(packages));
      expect(pubPackages.next, equals("http://pub.dartlang.org/packages.json?page=2"));
      expect(pubPackages.pages, equals(15));
      expect(pubPackages.prev, isNull);
      expect(pubPackages.packages.length, equals(3));
      expect(pubPackages.packages[0], equals("http://pub.dartlang.org/packages/tags.json"));
    });
  });
}

void main() {
  testPackage();
  testPubPackages();
}
