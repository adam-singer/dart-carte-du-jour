library test_google_compute_engine_config;

import 'package:test/test.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

void main() {
  group('GoogleComputeEngineConfig', () {
    test('base constructor', () {
      GoogleComputeEngineConfig googleComputeEngineConfig =
          new GoogleComputeEngineConfig("123", "456", "blah@blah.com", "xyz");
      expect(googleComputeEngineConfig.projectId, equals("123"));
      expect(googleComputeEngineConfig.projectNumber, equals("456"));
      expect(googleComputeEngineConfig.serviceAccountEmail, equals("blah@blah.com"));
      expect(googleComputeEngineConfig.rsaPrivateKey, equals("xyz"));
    });

    test('fromJson', () {
      GoogleComputeEngineConfig googleComputeEngineConfig =
          new GoogleComputeEngineConfig("123", "456", "blah@blah.com", "xyz");
      //var json = googleComputeEngineConfig.toJson();
      // GoogleComputeEngineConfig googleComputeEngineConfig2 =
      //     new GoogleComputeEngineConfig.fromJson(json);
      expect(googleComputeEngineConfig.projectId, equals("123"));
      expect(googleComputeEngineConfig.projectNumber, equals("456"));
      expect(googleComputeEngineConfig.serviceAccountEmail, equals("blah@blah.com"));
      expect(googleComputeEngineConfig.rsaPrivateKey, equals("xyz"));
    });

    test('toJson', () {
      GoogleComputeEngineConfig googleComputeEngineConfig =
          new GoogleComputeEngineConfig("123", "456", "blah@blah.com", "xyz");
      var json = googleComputeEngineConfig.toJson();
      expect(json['projectId'], equals('123'));
      expect(json['projectNumber'], equals('456'));
      expect(json['serviceAccountEmail'], equals('blah@blah.com'));
      expect(json['rsaPrivateKey'], equals('xyz'));
    });

    test('toString', () {
      GoogleComputeEngineConfig googleComputeEngineConfig =
          new GoogleComputeEngineConfig("123", "456", "blah@blah.com", "xyz");
      var jsonString = googleComputeEngineConfig.toString();
      expect('{"projectId":"123","projectNumber":"456","serviceAccountEmail":"blah@blah.com","rsaPrivateKey":"xyz"}', equals(jsonString));
    });
  });
}
