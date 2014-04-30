library test_client_builder_config;

import 'package:unittest/unittest.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

void main() {
  group('ClientBuilderConfig', () {
    test('base constructor', () {
      ClientBuilderConfig clientBuilderConfig = new ClientBuilderConfig("/somepath", null, null);
      expect(clientBuilderConfig.id, isNotNull);
      expect(clientBuilderConfig.id is String, isTrue);
      expect(clientBuilderConfig.sdkPath, equals("/somepath"));
    });

    // TODO: parse map
    // TODO: to string
    // TODO: store file
    // TODO: copy file to cloud (mock)
  });
}