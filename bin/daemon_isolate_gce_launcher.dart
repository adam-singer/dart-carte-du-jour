import 'dart:io';
import "dart:async";
import 'dart:isolate';
import 'dart:collection';
import 'dart:convert';

import 'package:quiver/collection.dart';
import 'package:logging/logging.dart';
import 'package:route/server.dart';
import 'package:route/url_pattern.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

final int MAX_GCE_INSTANCES = 15;

class IsolateGceLauncher {
  Duration _timeout = const Duration(seconds: 1);
  Timer _timer;
  GoogleComputeEngineConfig _googleComputeEngineConfig;
  String _sdkPath;

  Queue<Package> buildQueue = new Queue<Package>();
  Queue<Package> buildingQueue = new Queue<Package>();
  Queue<Package> completedQueue = new Queue<Package>();

  Isolate buildIndexIsolate;

  ReceivePort isolateQueueServiceReceivePort = new ReceivePort();
  ReceivePort isolateBuildIndexReceivePort = new ReceivePort();

  SendPort isolateQueueServiceSendPort;
  SendPort isolateBuildIndexSendPort;

  IsolateGceLauncher(this.isolateQueueServiceSendPort);

  void start() {
    Isolate.spawnUri(Uri.parse("daemon_isolate_build_index.dart"), ["init"],
        isolateBuildIndexReceivePort.sendPort).then((Isolate buildIndexIsolate) {
      this.buildIndexIsolate = buildIndexIsolate;
      return;
    }).then((_) {
      isolateQueueServiceSendPort.send(isolateQueueServiceReceivePort.sendPort);
      _initConfig();
      _initListeners();
      _initServer();
      Timer.run(callback);
    });
  }

  void stop() {
    _timer.cancel();
  }

  void callback() {
    if (buildingQueue.length < MAX_GCE_INSTANCES && buildQueue.isNotEmpty) {
      // TODO: query GCE instead of keeping local counter.
      Package package = buildQueue.removeFirst();
      buildingQueue.add(package);

      Logger.root.finest("buildingQueue.length = ${buildingQueue.length}");

      ClientBuilderConfig clientBuilderConfig =
          new ClientBuilderConfig(_sdkPath, _googleComputeEngineConfig, [package]);
      int result = clientBuilderConfig.storeConfigSync();
      if (result != 0) {
        // Some error happened
        Logger.root.severe("storeConfigSync failed = $result");
      }

      // TODO: support builder version ranges
      package.deployDocumentationBuilder(package.versions.first);

    } else {
      // TODO: check the current number of build instances on gce
      Logger.root.finest("waiting till available gce instance or buildQueue is empty");
    }

    // TODO: Might be better to check if the `package_build_info.json`
    // file was uploaded.
    completedQueue.addAll(buildingQueue
        .where((p) => !p.documentationInstanceAlive(p.versions.first)).toList());

    while (completedQueue.isNotEmpty) {
      // TODO: only send what has been completed.
      Package completedPackage = completedQueue.removeFirst();

      isolateQueueServiceSendPort.send(
          createMessage(GceLauncherCommand.PACKAGE_BUILD_COMPLETE,
                        completedPackage));

      if (isolateBuildIndexSendPort != null) {
        isolateBuildIndexSendPort.send(
                  createMessage(GceLauncherCommand.PACKAGE_BUILD_COMPLETE,
                                completedPackage));
      }

      buildingQueue.removeWhere((p) => p.name == completedPackage.name
          && listsEqual(p.versions, completedPackage.versions));
    }

    new Timer(_timeout, callback);
  }

  void _initConfig() {
    // TODO: remove hard coded config
    String configFile = new File("bin/config.json").readAsStringSync();
    Map config = JSON.decode(configFile);
    // TODO: remove this hack for something better.
    String rsaPrivateKey = new File(config["rsaPrivateKey"]).readAsStringSync();
    assert(rsaPrivateKey != null);
    assert(rsaPrivateKey.isNotEmpty);

    _googleComputeEngineConfig =
      new GoogleComputeEngineConfig(config["projectId"], config["projectNumber"],
          config["serviceAccountEmail"], rsaPrivateKey);

    _sdkPath = config["sdkPath"];
  }

  void _initListeners() {
    isolateQueueServiceReceivePort.listen((data) {
      // TODO: try out hashmaps of functions resolved by command string
      // Create command interface here.
      if (isCommand(QueueCommand.BUILD_PACKAGE, data)) {
        Package package = new Package.fromJson(data['message']);
        bool isInQueue = buildQueue.any((Package p) =>
                  p.name == package.name && listsEqual(p.versions, package.versions));

        if (!isInQueue) {
          buildQueue.add(package);
        }

        Logger.root.finest("buildQueue = ${buildQueue.toList()}");
        Logger.root.finest("buildQueue.length = ${buildQueue.length}");
      }
    });

    isolateBuildIndexReceivePort.listen((data) {
      if (data is SendPort) {
        isolateBuildIndexSendPort = data;
      }
    });
  }

  void _initServer() {
    final buildUrl = new UrlPattern(r'/build/(.*)\/(.*)');

    void build(req) {
      List<String> args = buildUrl.parse(req.uri.path);
      var packageName = args[0];
      var packageVersion = args[1];
      Version version = new Version.parse(packageVersion);
      Package package = new Package(packageName, [version], uploaders: []);
      buildQueue.add(package);
      req.response.write('queue $packageName $packageVersion');
      req.response.close();
    }

// Callback to handle illegal urls.
    void serveNotFound(req) {
      req.response.statusCode = HttpStatus.NOT_FOUND;
      req.response.write('Not found');
      req.response.close();
    }

    HttpServer.bind(InternetAddress.LOOPBACK_IP_V4, 8888).then((server) {
      var router = new Router(server)
        // Associate callbacks with URLs.
        ..serve(buildUrl, method: 'GET').listen(build)
        ..defaultStream.listen(serveNotFound);
    });
  }
}

void main(List<String> args, SendPort replyTo) {
  Logger.root.onRecord.listen((LogRecord record) {
    print("gce_launcher: ${record.message}");
  });

  Logger.root.finest("starting gce launcher");
  Logger.root.finest("args = $args");

  IsolateGceLauncher isolateGceLauncher = new IsolateGceLauncher(replyTo);
  isolateGceLauncher.start();
}
