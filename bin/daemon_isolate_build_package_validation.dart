import 'dart:io';
import 'dart:isolate';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:route/server.dart';
import 'package:route/url_pattern.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

final String COFNIG_FILE = "bin/config.json";

class IsolateBuildPackageValidation {
  GoogleComputeEngineConfig _googleComputeEngineConfig;

  ReceivePort isolateQueueServiceReceivePort = new ReceivePort();

  SendPort isolateQueueServiceSendPort;

  IsolateBuildPackageValidation(this.isolateQueueServiceSendPort);

  void start() {
    isolateQueueServiceSendPort.send(isolateQueueServiceReceivePort.sendPort);
    _initConfig();
    _initListeners();
    _initServer();
  }

  void stop() {
    // TODO: clean up lisenters and close ports.
  }

  void _initConfig() {
    // TODO: duplicate code from daemon_isolate_gce_launcher.dart
    // TODO: remove hard coded config
    String configFile = new File(COFNIG_FILE).readAsStringSync();
    Map config = JSON.decode(configFile);
    // TODO: remove this hack for something better.
    String rsaPrivateKey = new File(config["rsaPrivateKey"]).readAsStringSync();
    assert(rsaPrivateKey != null);
    assert(rsaPrivateKey.isNotEmpty);

    _googleComputeEngineConfig =
      new GoogleComputeEngineConfig(config["projectId"], config["projectNumber"],
          config["serviceAccountEmail"], rsaPrivateKey);
  }

  void _initServer() {
    final healthCheckUrl = new UrlPattern(r'/health');
    final SERVER_PORT = 8886;

    void health(HttpRequest req) {
      req.response.statusCode = HttpStatus.OK;
      req.response.writeln('All systems a go');
      req.response.close();
    }

    // Callback to handle illegal urls.
    void serveNotFound(HttpRequest req) {
      req.response.statusCode = HttpStatus.NOT_FOUND;
      req.response.write('Not found');
      req.response.close();
    }

    HttpServer.bind(InternetAddress.LOOPBACK_IP_V4, SERVER_PORT).then((server) {
      new Router(server)
        // Associate callbacks with URLs.
        ..serve(healthCheckUrl, method: 'GET').listen(health)
        ..defaultStream.listen(serveNotFound);
    });
  }

  void _initListeners() {
    isolateQueueServiceReceivePort.listen((data) {
      // Create command interface here.
      if (isCommand(QueueCommand.CHECK_PACKAGE, data)) {
        Package package = new Package.fromJson(data['message']);
        Package packageBuild = new Package(package.name, <Version>[], uploaders: []);

        // TODO: might be very wasteful to create a new PackageBuildInfoDataStore
        // on each CHECK_PACKAGE
        package.checkVersionBuilds(new PackageBuildInfoDataStore(_googleComputeEngineConfig))
        .listen((VersionBuild versionBuild) {
          Logger.root.finest("versionBuild = [${versionBuild.name}, ${versionBuild.version}, ${versionBuild.build}]");
          if (versionBuild.build) {
            packageBuild.versions.add(versionBuild.version);
          }
        }, onError: (error) {
          Logger.root.severe("QueueCommand.CHECK_PACKAGE stream error $error");
        }, onDone: () {
          if (packageBuild.versions.isNotEmpty) {
            isolateQueueServiceSendPort
            .send(createMessage(PackageValidationCommand.PACKAGE_ADD_OUTBOX,
                                packageBuild));
          }

          // Remove package from inbox, fully processed
          isolateQueueServiceSendPort
           .send(createMessage(PackageValidationCommand.PACKAGE_REMOVE_INBOX,
               package));
        }, cancelOnError: true);
      } else if (isCommand(QueueCommand.FORCE_PACKAGE, data)) {
        Package package = new Package.fromJson(data['message']);
        isolateQueueServiceSendPort
         .send(createMessage(PackageValidationCommand.PACKAGE_ADD_OUTBOX, package));
      }
    });
  }
}

void main(List<String> args, SendPort replyTo) {
  Logger.root.onRecord.listen((LogRecord record) {
    print("build_package: ${record.message}");
  });

  Logger.root.finest("starting build package validation");
  Logger.root.finest("args = $args");
  Logger.root.finest("replyTo = $replyTo");

  IsolateBuildPackageValidation isolateBuildPackageValidation = new IsolateBuildPackageValidation(replyTo);
  isolateBuildPackageValidation.start();
}
