part of carte_de_jour;

class GoogleComputeEngineConfig {
  final String projectId;
  final String projectNumber;
  final String serviceAccountEmail;
  final String rsaPrivateKey;
  GoogleComputeEngineConfig(this.projectId, this.projectNumber,
      this.serviceAccountEmail, this.rsaPrivateKey);
}

class PackageBuildInfoDataStore {
  GoogleComputeEngineConfig _googleComputeEngineConfig;
  final String _scopes = 'https://www.googleapis.com/auth/userinfo.email '
      'https://www.googleapis.com/auth/datastore';

  ComputeOAuth2Console _computeEngineClient;
  console.Datastore _datastore;

  PackageBuildInfoDataStore(this._googleComputeEngineConfig) {
    _computeEngineClient = new ComputeOAuth2Console(
        _googleComputeEngineConfig.projectNumber,
        privateKey: _googleComputeEngineConfig.rsaPrivateKey,
        iss: _googleComputeEngineConfig.serviceAccountEmail,
        scopes: _scopes);

    _datastore = new console.Datastore(_computeEngineClient)
    ..makeAuthRequests = true;
  }

  // TODO: look up the entity first before commiting it.
  Future<bool> save(PackageBuildInfo packageBuildInfo) {
    client.Key key;
    String transaction;

    var beginTransactionRequest = new client.BeginTransactionRequest.fromJson({});
    return _datastore.datasets.beginTransaction(beginTransactionRequest, _googleComputeEngineConfig.projectId)
        .then((client.BeginTransactionResponse beginTransactionResponse) {
      // Get the transaction handle from the response.
      transaction = beginTransactionResponse.transaction;

      // Create a RPC request to get entities by key.
      var lookupRequest = new client.LookupRequest.fromJson({});

      // Create a new entities by key
      key = new client.Key.fromJson({});

      // Set the entity key with only one `path_element`: no parent.
      var path = new client.KeyPathElement.fromJson({
        'kind': 'PackageBuildInfo',
        'name': '${packageBuildInfo.name}-${packageBuildInfo.version}'
      });

      key.path = new List<client.KeyPathElement>();
      key.path.add(path);
      lookupRequest.keys = new List<client.Key>();

      // Add one key to the lookup request.
      lookupRequest.keys.add(key);

      // Set the transaction, so we get a consistent snapshot of the
      // entity at the time the transaction started.
      lookupRequest.readOptions = new client.ReadOptions.fromJson({
        'transaction': transaction
      });

      // Execute the RPC and get the response.
      return _datastore.datasets.lookup(lookupRequest, _googleComputeEngineConfig.projectId);
    }).then((client.LookupResponse lookupResponse) {

      // Create a RPC request to commit the transaction.
      var req = new client.CommitRequest.fromJson({});

      // Set the transaction to commit.
      req.transaction = transaction;

      // If no entity was found, insert a new one in the commit request mutation.
      client.Entity entity;
      req.mutation = new client.Mutation.fromJson({});
      // TODO: update is used if the entity exists.
      if (lookupResponse.found.isNotEmpty) {
        entity = lookupResponse.found.first.entity;
        req.mutation.update = new List<client.Entity>();
        req.mutation.update.add(entity);
      } else {
        entity = new client.Entity.fromJson({});
        req.mutation.insert = new List<client.Entity>();
        req.mutation.insert.add(entity);
      }

      // Copy the entity key.
      entity.key = new client.Key.fromJson(key.toJson());
      entity.properties = new Map<String, client.Property>();

      client.Property property = new client.Property.fromJson({});
      property.stringValue = packageBuildInfo.name;
      property.indexed = true;
      entity.properties['name'] = property;

      property = new client.Property.fromJson({});
      property.stringValue = packageBuildInfo.version.toString();
      property.indexed = false;
      entity.properties['version'] = property;

      property = new client.Property.fromJson({});
      property.booleanValue = packageBuildInfo.isBuilt;
      property.indexed = true;
      entity.properties['isBuilt'] = property;

      property = new client.Property.fromJson({});
      property.dateTimeValue = packageBuildInfo.datetime;
      property.indexed = true;
      entity.properties['lastBuild'] = property;

      property = new client.Property.fromJson({});
      property.stringValue = packageBuildInfo.buildLog;
      property.indexed = false;
      entity.properties['lastBuildLog'] = property;

      // Execute the Commit RPC synchronously and ignore the response:
      // Apply the insert mutation if the entity was not found and close
      // the transaction.
      return _datastore.datasets.commit(req, _googleComputeEngineConfig.projectId);
    }).then((client.CommitResponse commitResponse) {
      return true;
    });
  }

  Future<PackageBuildInfo> fetch(String name, Version version) {
    client.Key key;
    String transaction;
    var beginTransactionRequest = new client.BeginTransactionRequest.fromJson({});

    return _datastore.datasets.beginTransaction(beginTransactionRequest, _googleComputeEngineConfig.projectId)
            .then((client.BeginTransactionResponse beginTransactionResponse) {

      // Get the transaction handle from the response.
      transaction = beginTransactionResponse.transaction;

      // Create a RPC request to get entities by key.
      var lookupRequest = new client.LookupRequest.fromJson({});

      // Create a new entities by key
      key = new client.Key.fromJson({});

      // Set the entity key with only one `path_element`: no parent.
      var path = new client.KeyPathElement.fromJson({
        'kind': 'PackageBuildInfo',
        'name': '${name}-${version}'
      });

      key.path = new List<client.KeyPathElement>();
      key.path.add(path);
      lookupRequest.keys = new List<client.Key>();

      // Add one key to the lookup request.
      lookupRequest.keys.add(key);

      // Set the transaction, so we get a consistent snapshot of the
      // entity at the time the transaction started.
      lookupRequest.readOptions = new client.ReadOptions.fromJson({
        'transaction': transaction
      });

      // Execute the RPC and get the response.
      return _datastore.datasets.lookup(lookupRequest, _googleComputeEngineConfig.projectId);
    }).then((client.LookupResponse lookupResponse) {
      if (lookupResponse.found.isEmpty) {
        return null;
      }

      client.Entity entity = lookupResponse.found.first.entity;

      String name = entity.properties['name'].stringValue;
      Version version = new Version.parse(entity.properties['version'].stringValue);
      String datetime = entity.properties['lastBuild'].dateTimeValue;
      bool isBuilt = entity.properties['isBuilt'].booleanValue;
      return new PackageBuildInfo(name, version, datetime, isBuilt);
    });
  }

  Future<List<PackageBuildInfo>> fetchBuilt([bool isBuilt = true]) {
    client.Query query = new client.Query.fromJson({
      "kinds": [{ "name": 'PackageBuildInfo' }],
      "filter": {
        "propertyFilter": {
          "property": { "name": 'isBuilt' },
          "operator": 'EQUAL',
          "value": { "booleanValue": isBuilt }
        }
      }
    });

    client.RunQueryRequest runQueryRequest = new client.RunQueryRequest.fromJson({});
    runQueryRequest.query = query;

    return _datastore.datasets.runQuery(runQueryRequest, _googleComputeEngineConfig.projectId)
    .then((client.RunQueryResponse runQueryResponse) {
      List<PackageBuildInfo> packageBuildInfos = new List<PackageBuildInfo>();
      runQueryResponse.batch.entityResults.forEach((client.EntityResult entityResult) {
        String name = entityResult.entity.properties["name"].stringValue;
        Version version = new Version.parse(entityResult.entity.properties["version"].stringValue);
        bool isBuilt = entityResult.entity.properties["isBuilt"].booleanValue;
        String datetime = entityResult.entity.properties["lastBuild"].dateTimeValue;
        String buildLog = entityResult.entity.properties["lastBuildLog"].stringValue;
        packageBuildInfos.add(new PackageBuildInfo(name, version, datetime, isBuilt));
      });
      return packageBuildInfos;
    });
  }
}
