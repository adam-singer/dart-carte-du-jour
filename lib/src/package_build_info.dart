part of carte_de_jour;

/**
 * Class representation of package_build_info.json file.
 */
class PackageBuildInfo {
  String name;
  Version version;
  String datetime;
  bool isBuilt;
  String buildLog;

  PackageBuildInfo(this.name, this.version, this.datetime, this.isBuilt, [this.buildLog = ""]);

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

    if (data.containsKey("buildLog")) {
      buildLog = data["buildLog"];
    }
  }

  String toString() => JSON.encode(toJson());

  Map toJson() {
    Map data = new Map();
    data["name"] = name;
    data["version"] = version.toString();
    data["datetime"] = datetime;
    data["isBuilt"] = isBuilt;
    data["buildLog"] = buildLog;
    return data;
  }
}
