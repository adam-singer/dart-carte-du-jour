library test_google_compute_engine_config;

import 'package:unittest/unittest.dart';

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
  });
}