library test_client_builder_config;

import 'dart:convert';

import 'package:unittest/unittest.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

void main() {
  group('ClientBuilderConfig', () {
    test('base constructor', () {
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
      List<Package> packages = [new Package.fromJson(JSON.decode(unittestPackageModel))];
      GoogleComputeEngineConfig googleComputeEngineConfig =
              new GoogleComputeEngineConfig("123", "456", "blah@blah.com", "xyz");

      ClientBuilderConfig clientBuilderConfig = new ClientBuilderConfig("/somepath", googleComputeEngineConfig, packages);
      expect(clientBuilderConfig.id, isNotNull);
      expect(clientBuilderConfig.id is String, isTrue);
      expect(clientBuilderConfig.sdkPath, equals("/somepath"));
      expect(clientBuilderConfig.packages, isNotNull);
      expect(clientBuilderConfig.packages.length, equals(1));
      expect(clientBuilderConfig.packages.first.name, equals("unittest"));
      expect(clientBuilderConfig.googleComputeEngineConfig, isNotNull);
      expect(clientBuilderConfig.googleComputeEngineConfig.projectId, equals("123"));
    });

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
      List<Package> packages = [new Package.fromJson(JSON.decode(unittestPackageModel))];
      GoogleComputeEngineConfig googleComputeEngineConfig =
              new GoogleComputeEngineConfig("123", "456", "blah@blah.com", "xyz");


      ClientBuilderConfig clientBuilderConfig = new ClientBuilderConfig("/somepath", googleComputeEngineConfig, packages);
      var json = clientBuilderConfig.toJson();
      clientBuilderConfig = new ClientBuilderConfig.fromJson(json);
      expect(clientBuilderConfig.id, isNotNull);
      expect(clientBuilderConfig.id is String, isTrue);
      expect(clientBuilderConfig.sdkPath, equals("/somepath"));
      expect(clientBuilderConfig.packages, isNotNull);
      expect(clientBuilderConfig.packages.length, equals(1));
      expect(clientBuilderConfig.packages.first.name, equals("unittest"));
      expect(clientBuilderConfig.googleComputeEngineConfig, isNotNull);
      expect(clientBuilderConfig.googleComputeEngineConfig.projectId, equals("123"));
    });

    test('toString', () {
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
      List<Package> packages = [new Package.fromJson(JSON.decode(unittestPackageModel))];
      GoogleComputeEngineConfig googleComputeEngineConfig =
              new GoogleComputeEngineConfig("123", "456", "blah@blah.com", "xyz");

      ClientBuilderConfig clientBuilderConfig = new ClientBuilderConfig("/somepath", googleComputeEngineConfig, packages);
      String id = clientBuilderConfig.id;
      String jsonString = clientBuilderConfig.toString();

      expect(jsonString, equals('{"id":"$id","sdkPath":"/somepath","googleComputeEngineConfig":{"projectId":"123","projectNumber":"456","serviceAccountEmail":"blah@blah.com","rsaPrivateKey":"xyz"},"packages":[{"name":"unittest","versions":["0.10.0","0.10.1","0.10.1+1"],"uploaders":["dgrove@google.com","jmesserly@google.com"]}]}'));
    });

//    // TODO: store file
//    test('store file', () {
//
//    });
//
//    // TODO: copy file to cloud (mock)
//    test('copy file', () {
//
//    });
  });
}
