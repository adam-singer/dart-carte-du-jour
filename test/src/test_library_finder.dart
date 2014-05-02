library test_library_finder;

import 'package:unittest/unittest.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

void main() {
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
