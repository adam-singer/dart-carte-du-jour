part of carte_de_jour;

class GoogleComputeEngineConfig {
  final String projectId;
  final String projectNumber;
  final String serviceAccountEmail;
  final String rsaPrivateKey;
  GoogleComputeEngineConfig(this.projectId, this.projectNumber,
      this.serviceAccountEmail, this.rsaPrivateKey);

  factory GoogleComputeEngineConfig.fromJson(Map data) {
    String _projectId;
    String _projectNumber;
    String _serviceAccountEmail;
    String _rsaPrivateKey;

    if (data.containsKey('projectId')) {
      _projectId = data["projectId"];
    }

    if (data.containsKey('projectNumber')) {
      _projectNumber = data["projectNumber"];
    }

    if (data.containsKey('serviceAccountEmail')) {
      _serviceAccountEmail = data["serviceAccountEmail"];
    }

    if (data.containsKey('rsaPrivateKey')) {
      _rsaPrivateKey = data["rsaPrivateKey"];
    }

    return new GoogleComputeEngineConfig(_projectId, _projectNumber,
        _serviceAccountEmail, _rsaPrivateKey);
  }

  Map toJson() {
    Map map = {};
    map['projectId'] = projectId;
    map['projectNumber'] = projectNumber;
    map['serviceAccountEmail'] = serviceAccountEmail;
    map['rsaPrivateKey'] = rsaPrivateKey;
    return map;
  }

  String toString() => JSON.encode(toJson());
}