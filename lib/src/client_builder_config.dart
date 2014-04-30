part of carte_de_jour;

class ClientBuilderConfig {
  final String id;
  final String sdkPath;
  final GoogleComputeEngineConfig googleComputeEngineConfig;
  final List<Package> packages;

  ClientBuilderConfig._(this.id, this.sdkPath, this.googleComputeEngineConfig,
      this.packages);

  factory ClientBuilderConfig(sdkPath, googleComputeEngineConfig, packages) {

    return new ClientBuilderConfig._(uuid_generator.v4(), sdkPath,
        googleComputeEngineConfig, packages);
  }

  factory ClientBuilderConfig.fromJson(Map data) {
    String _id;
    String _sdkPath;
    GoogleComputeEngineConfig _googleComputeEngineConfig;
    List<Package> _packages;

    if (data.containsKey("id")) {
      _id = data["id"];
    }

    if (data.containsKey("sdkPath")) {
      _sdkPath = data["sdkPath"];
    }

    if (data.containsKey("googleComputeEngineConfig")) {
      _googleComputeEngineConfig = data["googleComputeEngineConfig"]
      .map((e) => new GoogleComputeEngineConfig.fromJson(e));
    }

    if (data.containsKey("packages")) {
      _packages = data["packages"].map((e) => new Package.fromJson(e)).toList();
    }

    return new ClientBuilderConfig._(_id, _sdkPath, _googleComputeEngineConfig,
        _packages);
  }

  Map toJson() {
    Map map = {};
    map['id'] = id;
    map['sdkPath'] = sdkPath;
    map['googleComputeEngineConfig'] = googleComputeEngineConfig;
    map['packages'] = packages;
    return map;
  }

  String toString() => JSON.encode(toJson());

  storeConfigSync() {
    // TODO: store configuration on cloud storage.
    // return the location of the configuration file stored.
    throw new UnimplementedError();
  }
}

