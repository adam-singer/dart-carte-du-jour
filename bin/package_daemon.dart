import "dart:io";
import "dart:async";

// TODO(adam): rename dart-carte-du-jour to dart_carte_du_jour
import 'package:dart-carte-du-jour/carte_de_jour.dart';

void main() {
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

  fetchPackages().then((PubPackages pubPackages) {
    return pubPackages.packages.map(fetchPackage).toList();
  }).then((List<Future<Package>> packages) {
    return Future.wait(packages);
  }).then((List<Package> packages) {
    packages.forEach((e) => print("name: ${e.name}"));
    return packages.map((e) => buildDocumentationCacheSync(e)).toList();
  }).then((List<int> cacheResults) {
    return cacheResults;
  }).then((List<int> results) {
    print("results = ${results}");
  });
}
