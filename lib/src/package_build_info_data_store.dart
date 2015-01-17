part of carte_de_jour;

class DatastoreConnection {
  final String _scopes = 'https://www.googleapis.com/auth/userinfo.email '
  'https://www.googleapis.com/auth/datastore';
  GoogleComputeEngineConfig _googleComputeEngineConfig;
  ComputeOAuth2Console _computeEngineClient;
  console.Datastore _datastore;

  console.Datastore get datastore {
    return _datastore;
  }

  DatastoreConnection(this._googleComputeEngineConfig) {
    _computeEngineClient = new ComputeOAuth2Console(
        _googleComputeEngineConfig.projectNumber,
        privateKey: _googleComputeEngineConfig.rsaPrivateKey,
        iss: _googleComputeEngineConfig.serviceAccountEmail,
        scopes: _scopes);
    _datastore = new console.Datastore(_computeEngineClient)
      ..makeAuthRequests = true;
  }

  void close() {
    // Safer way to close connection
    try {
      _computeEngineClient.close();
    } catch (ex) {
      Logger.root.severe("_computeEngineClient.close() Exception: ${ex}}");
    }
  }
}

class PackageBuildInfoDataStore {
  GoogleComputeEngineConfig _googleComputeEngineConfig;

  PackageBuildInfoDataStore(this._googleComputeEngineConfig);

  // TODO: look up the entity first before committing it.
  Future<bool> save(PackageBuildInfo packageBuildInfo) {
    DatastoreConnection datastoreConnection = new DatastoreConnection(_googleComputeEngineConfig);

    client.Key key;
    String transaction;

    var beginTransactionRequest = new client.BeginTransactionRequest.fromJson({});
    return datastoreConnection.datastore.datasets.beginTransaction(beginTransactionRequest, _googleComputeEngineConfig.projectId)
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
      return datastoreConnection.datastore.datasets.lookup(lookupRequest, _googleComputeEngineConfig.projectId);
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
      return datastoreConnection.datastore.datasets.commit(req, _googleComputeEngineConfig.projectId);
    }).then((client.CommitResponse commitResponse) {
      datastoreConnection.close();
      return true;
    }).catchError((error) {
      Logger.root.severe("Not able to save ${packageBuildInfo.toString()}: $error");
      return false;
    });
  }

  Future<PackageBuildInfo> fetch(String name, Version version) {
    DatastoreConnection datastoreConnection = new DatastoreConnection(_googleComputeEngineConfig);

    client.Key key;
    String transaction;
    var beginTransactionRequest = new client.BeginTransactionRequest.fromJson({});

    return datastoreConnection.datastore.datasets.beginTransaction(beginTransactionRequest, _googleComputeEngineConfig.projectId)
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
      return datastoreConnection.datastore.datasets.lookup(lookupRequest, _googleComputeEngineConfig.projectId);
    }).then((client.LookupResponse lookupResponse) {
      if (lookupResponse.found.isEmpty) {
        return null;
      }

      client.Entity entity = lookupResponse.found.first.entity;

      String name = entity.properties['name'].stringValue;
      Version version = new Version.parse(entity.properties['version'].stringValue);
      String datetime = entity.properties['lastBuild'].dateTimeValue;
      bool isBuilt = entity.properties['isBuilt'].booleanValue;
      datastoreConnection.close();
      return new PackageBuildInfo(name, version, datetime, isBuilt);
    }).catchError((error) {
      datastoreConnection.close();
      Logger.root.severe("Not able to fetch ${name}-${version}: $error");
      return false;
    });
  }

  Future<List<PackageBuildInfo>> fetchBuilt([bool isBuilt = true]) {
    DatastoreConnection datastoreConnection = new DatastoreConnection(_googleComputeEngineConfig);

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

    return datastoreConnection.datastore.datasets.runQuery(runQueryRequest, _googleComputeEngineConfig.projectId)
    .then((client.RunQueryResponse runQueryResponse) {
      List<PackageBuildInfo> packageBuildInfos = new List<PackageBuildInfo>();
      runQueryResponse.batch.entityResults.forEach((client.EntityResult entityResult) {
        String name = entityResult.entity.properties["name"].stringValue;
        Version version = new Version.parse(entityResult.entity.properties["version"].stringValue);
        bool isBuilt = entityResult.entity.properties["isBuilt"].booleanValue;
        String datetime = entityResult.entity.properties["lastBuild"].dateTimeValue;
        String buildLog = entityResult.entity.properties["lastBuildLog"].stringValue;
        packageBuildInfos.add(new PackageBuildInfo(name, version, datetime, isBuilt, buildLog));
      });

      datastoreConnection.close();
      return packageBuildInfos;
    }).catchError((error) {
      datastoreConnection.close();
      Logger.root.severe("Not able to fetchBuilt: $error");
      return new List<PackageBuildInfo>();
    });
  }
  
  // Fetch all the versions of a package with [name]
  Future<List<PackageBuildInfo>> fetchVersions(String name) {
    DatastoreConnection datastoreConnection = new DatastoreConnection(_googleComputeEngineConfig);

    client.RunQueryRequest runQueryRequest = new client.RunQueryRequest.fromJson({});
    runQueryRequest.gqlQuery = new client.GqlQuery.fromJson({});
    runQueryRequest.gqlQuery.queryString ='''
SELECT * FROM PackageBuildInfo 
  WHERE name = @n
''';

    runQueryRequest.gqlQuery.nameArgs = new List<client.GqlQueryArg>();
    client.GqlQueryArg arg = new client.GqlQueryArg.fromJson({});
    arg = new client.GqlQueryArg.fromJson({});
    arg.name = "n";
    arg.value =  new client.Value.fromJson({});
    arg.value.stringValue = name;
    runQueryRequest.gqlQuery.nameArgs.add(arg);

    return datastoreConnection.datastore.datasets.runQuery(runQueryRequest, _googleComputeEngineConfig.projectId)
        .then((client.RunQueryResponse runQueryResponse) {
      List<PackageBuildInfo> packageBuildInfos = new List<PackageBuildInfo>();
      runQueryResponse.batch.entityResults.forEach((client.EntityResult entityResult) {
        String name = entityResult.entity.properties["name"].stringValue;
        Version version = new Version.parse(entityResult.entity.properties["version"].stringValue);
        bool isBuilt = entityResult.entity.properties["isBuilt"].booleanValue;
        String datetime = entityResult.entity.properties["lastBuild"].dateTimeValue;
        String buildLog = entityResult.entity.properties["lastBuildLog"].stringValue;
        packageBuildInfos.add(new PackageBuildInfo(name, version, datetime, isBuilt, buildLog));
      });

      datastoreConnection.close();
      return packageBuildInfos;
    }).catchError((error) {
      datastoreConnection.close();
      Logger.root.severe("Not able to fetchBuilt: $error");
      return new List<PackageBuildInfo>();
    });
  }
  

  Future<List<PackageBuildInfo>> fetchHistory([int historyCount = 100]) {
    DatastoreConnection datastoreConnection = new DatastoreConnection(_googleComputeEngineConfig);

    client.RunQueryRequest runQueryRequest = new client.RunQueryRequest.fromJson({});
    runQueryRequest.gqlQuery = new client.GqlQuery.fromJson({});
    runQueryRequest.gqlQuery.queryString ='''
SELECT * FROM PackageBuildInfo 
  ORDER BY lastBuild DESC
  LIMIT @q
''';

    runQueryRequest.gqlQuery.nameArgs = new List<client.GqlQueryArg>();
    client.GqlQueryArg arg = new client.GqlQueryArg.fromJson({});
    arg = new client.GqlQueryArg.fromJson({});
    arg.name = "q";
    arg.value =  new client.Value.fromJson({});
    arg.value.integerValue = historyCount;
    runQueryRequest.gqlQuery.nameArgs.add(arg);

    return datastoreConnection.datastore.datasets.runQuery(runQueryRequest, _googleComputeEngineConfig.projectId)
        .then((client.RunQueryResponse runQueryResponse) {
      List<PackageBuildInfo> packageBuildInfos = new List<PackageBuildInfo>();
      runQueryResponse.batch.entityResults.forEach((client.EntityResult entityResult) {
        String name = entityResult.entity.properties["name"].stringValue;
        Version version = new Version.parse(entityResult.entity.properties["version"].stringValue);
        bool isBuilt = entityResult.entity.properties["isBuilt"].booleanValue;
        String datetime = entityResult.entity.properties["lastBuild"].dateTimeValue;
        String buildLog = entityResult.entity.properties["lastBuildLog"].stringValue;
        packageBuildInfos.add(new PackageBuildInfo(name, version, datetime, isBuilt, buildLog));
      });

      datastoreConnection.close();
      return packageBuildInfos;
    }).catchError((error) {
      datastoreConnection.close();
      Logger.root.severe("Not able to fetchBuilt: $error");
      return new List<PackageBuildInfo>();
    });
  }
}
