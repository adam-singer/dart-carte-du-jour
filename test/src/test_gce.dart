library test_gce;

import 'package:unittest/unittest.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

void main() {
  group('gce instance name', () {
    test('scrub instance name', () {
      String packageName = "database_reverse_engineer";
      String gce_name = buildGceName(packageName,  new Version.parse("0.0.1"));
      expect(gce_name, equals("b-databasereverseengi-2b5a2f1b52"));
    });

    test('scrub long instance name', () {
      String packageName = "database_reverse_engineer_baam_baam_waam_package_awesome_balm_wam_slam_jam";

      String gce_name = buildGceName(packageName, new Version.parse("0.0.1"));
      expect(gce_name, equals("b-databasereverseengi-2b5a2f1b52"));
    });
  });
}