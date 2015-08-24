library test_version;

import 'package:test/test.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

void main() {
  group('Version', () {
    test('toString', () {
      Version version = new Version.parse("0.10.0");
      expect(version.toString(), equals("0.10.0"));
    });

    test('compare', () {
      Version version0 = new Version.parse("0.10.0");
      expect(version0.toString(), equals("0.10.0"));

      Version version1 = new Version.parse("0.10.1");
      expect(version1.toString(), equals("0.10.1"));

      expect(version0 > version1, isFalse);
      expect(version0 < version1, isTrue);
      expect(version0 == version1, isFalse);

      Version version2 = new Version.parse("0.10.1-pre");
      expect(version2.isPreRelease, isTrue);
      expect(version0.isPreRelease, isFalse);

      String metadataVersion = "version:${version2}";
      expect(metadataVersion, equals("version:0.10.1-pre"));
    });

    test('sort', () {
      Version version_0_0_1_pre = new Version.parse("0.0.1-pre");
      Version version_0_0_1 = new Version.parse("0.0.1");
      Version version_0_0_2 = new Version.parse("0.0.2");
      Version version_0_0_3 = new Version.parse("0.0.3");
      Version version_0_1_3 = new Version.parse("0.1.3");
      Version version_0_1_3_pre = new Version.parse("0.1.3-pre");
      Version version_0_1_4 = new Version.parse("0.1.4");
      Version version_1_0_3 = new Version.parse("1.0.3");
      Version version_1_0_3_pre = new Version.parse("1.0.3-pre");
      Version version_1_0_4_pre = new Version.parse("1.0.4-pre");
      List<Version> versions = [version_0_0_1_pre, version_0_0_1, version_0_0_2,
                                version_0_0_3, version_0_1_3, version_0_1_3_pre,
                                version_0_1_4, version_1_0_3, version_1_0_3_pre,
                                version_1_0_4_pre];
      versions.sort();
      expect(versions.last, equals(version_1_0_4_pre));
      expect(versions.toString(), equals("[0.0.1-pre, 0.0.1, 0.0.2, 0.0.3, "
          "0.1.3-pre, 0.1.3, 0.1.4, 1.0.3-pre, 1.0.3, 1.0.4-pre]"));
    });
  });
}
