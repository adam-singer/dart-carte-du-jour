library carte_de_jour;

class Package {
  List<String> uploaders;
  String name;
  List<String> versions;
  Package.fromJson(Map data) {
    uploaders = new List<String>();
    if (data.containsKey('uploaders')) {
      for (var u in data['uploaders']) {
        uploaders.add(u);
      }
    }

    if (data.containsKey('name')) {
      name = data['name'];
    }

    versions = new List<String>();
    if (data.containsKey('versions')) {
      versions.addAll(data['versions'].toList());
    }
  }
}

class PubPackages {
  String prev;
  List<String> packages;
  String pages;
  String next;
  PubPackages.fromJson(Map data) {
    if (data.containsKey('prev')) {
      prev = data['prev'];
    }

    if (data.containsKey('pages')) {
      pages = data['pages'];
    }

    if (data.containsKey('next')) {
      next = data['next'];
    }

    packages = new List<Package>();
    if (data.containsKey('packages')) {
      for (var p in data['packages']) {
        packages.add(p);
      }
    }
  }
}

String generatePubSpecFile(String packageName, String packageVersion, String mockPackageName) {
  StringBuffer pubSpecData = new StringBuffer()
  ..writeln("name: $mockPackageName")
  ..writeln("dependencies:")
  ..writeln("  $packageName: '$packageVersion'");
  return pubSpecData.toString();
}

build_docs() {
  //
}

fetch_packages() {

}

