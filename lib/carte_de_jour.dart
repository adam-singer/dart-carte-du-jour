library carte_de_jour;

class Version {

}

class Package {
  List<String> uploaders;
  String name;
  List<Version> versions;
}

class PubPackages {
  String prev;
  List<Package> packages;
  String pages;
  String next;
}

