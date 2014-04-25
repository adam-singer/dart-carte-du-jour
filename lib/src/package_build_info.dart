part of carte_de_jour;

/**
 * Class representation of package_build_info.json file.
 */
class PackageBuildInfo {
  String name;
  Version version;
  String datetime;
  bool isBuilt;

  PackageBuildInfo(this.name, this.version, this.datetime, this.isBuilt);

  PackageBuildInfo.fromJson(Map data) {
    if (data.containsKey("name")) {
      name = data["name"];
    }

    if (data.containsKey("version")) {
      version = new Version.parse(data["version"]);
    }

    if (data.containsKey("datetime")) {
      datetime = data["datetime"];
    }

    if (data.containsKey("isBuilt")) {
      isBuilt = data['isBuilt'];
    }
  }

  String toString() {
    Map data = new Map();
    data["name"] = name;
    data["version"] = version.toString();
    data["datetime"] = datetime;
    data["isBuilt"] = isBuilt;
    return JSON.encode(data);
  }
}
