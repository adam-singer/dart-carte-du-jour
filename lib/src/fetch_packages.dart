part of carte_de_jour;

/**
 * Fetch packages.json file and return PubPackages
 */
Future<PubPackages> fetchPackages([int page]) {
  String uri = PACKAGES_DATA_URI + (page != null ? "?page=${page}":"");
  return http.get(uri).then((response) {
    if (response.statusCode != 200) {
      Logger.root.warning("Not able to fetch packages: ${response.statusCode}:${response.body}");
      return null;
    }

    var data = JSON.decode(response.body);
    PubPackages pubPackages = new PubPackages.fromJson(data);
    return pubPackages;
  });
}

/**
 * Fetch all pages of packages.json file and return as `List` of
 * `PubPackages` objects.
 */
Future<List<PubPackages>> fetchAllPackages() {
  Completer completer = new Completer();
  List pubPackages = [];
  int pageCount = 1;

  void callback() {
    fetchPackages(pageCount).then((PubPackages p) {
      Logger.root.finest("pageCount = ${pageCount}");
      if (p.packages.length == 0) {
        completer.complete(pubPackages);
        return;
      }

      pageCount++;
      pubPackages.add(p);
      Timer.run(callback);
    });
  }

  Timer.run(callback);
  return completer.future;
}

/**
 * Fetch a particular `<package>.json` file and return `Package`
 */
Future<Package> fetchPackage(String packageJsonUri) {
  return http.get(packageJsonUri).then((response) {
    if (response.statusCode != 200) {
      Logger.root.warning("Not able to fetch packages: ${response.statusCode}:${response.body}");
      return null;
    }

    var data = JSON.decode(response.body);
    Package package = new Package.fromJson(data);
    return package;
  });
}

/**
 * Fetches all the packages and puts them into `Package` objects
 */
Future<List<Package>> fetchAllPackage() {
  return fetchAllPackages().then((List<PubPackages> pubPackages) {
   Completer completer = new Completer();
   List<String> packagesUris = new List<String>();
   pubPackages.forEach((PubPackages pubPackages) =>
       packagesUris.addAll(pubPackages.packages));

   List<Package> packages = new List<Package>();
   void callback() {
     if (packagesUris.isEmpty) {
       completer.complete(packages);
       return;
     }

     print("fetching ${packagesUris.last}");
     fetchPackage(packagesUris.removeLast()).then((Package package) {
       packages.add(package);
       Timer.run(callback);
     });
   }

   Timer.run(callback);
   return completer.future;
  });
}
