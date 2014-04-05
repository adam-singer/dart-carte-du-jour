import 'dart:convert';

import 'package:unittest/unittest.dart';
import 'package:unittest/vm_config.dart';

// TODO(adam): rename dart-carte-du-jour to dart_carte_du_jour
import 'package:dart-carte-du-jour/carte_de_jour.dart';

void main() {

  group('pub spec', () {
    test('create pub spec', () {
      String packageName = "unittest";
      String packageVersion = "0.10.0";
      String mockPackageName = "mock_unittest";


      String pubSpecFile = generatePubSpecFile(packageName, packageVersion, mockPackageName);
      String pubSpecFileExpected = """name: mock_unittest
dependencies:
  unittest: '0.10.0'
""";
      expect(pubSpecFile, pubSpecFileExpected);
    });
  });

  group('models', () {
    test('Package.fromJson', () {
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
      expect(package.versions.contains('0.10.0'), isTrue);
      expect(package.uploaders.length, equals(2));
      expect(package.uploaders.contains('dgrove@google.com'), isTrue);

    });

    test('PubPackages.fromJson', () {
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

  group('findDartLibraryFiles', () {
    test('all libraries', () {
      List<String> libs = findDartLibraryFiles('test/dummyLibraries/allLibs');
      expect(libs.length, equals(2));

    });
    test('no libraries', () {
      List<String> libs = findDartLibraryFiles('test/dummyLibraries/noLibs');
      expect(libs.length, equals(0));
    });
    test('mixed libraries and part of', () {
      List<String> libs = findDartLibraryFiles('test/dummyLibraries/mixedLibs');
      expect(libs.length, equals(3));
    });
  });
}
