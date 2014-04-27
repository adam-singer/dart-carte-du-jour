import "dart:io";
import "dart:async";
import 'dart:isolate';
import 'dart:collection';
import "dart:convert";

import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:mustache/mustache.dart' as mustache;

import 'package:dart_carte_du_jour/carte_de_jour.dart';

class IsolateBuildIndex {
  Duration _timeout = const Duration(seconds: 10);
  Timer _timer;
  PackageBuildInfoDataStore _packageBuildInfoDataStore;
  GoogleComputeEngineConfig _googleComputeEngineConfig;

  // Stack up a queue of completed objects. Empty out on each index build.
  Queue<Package> isBuiltQueue = new Queue<Package>();

  ReceivePort isolateGceLauncherReceivePort = new ReceivePort();
  SendPort isolateGceLauncherSendPort;
  IsolateBuildIndex(this.isolateGceLauncherSendPort);

  void start() {
    isolateGceLauncherSendPort.send(isolateGceLauncherReceivePort.sendPort);
    _initListeners();
    _initDatastore();
    Timer.run(callback);
  }

  void stop() {
    _timer.cancel();
  }

  void _initDatastore() {
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

    _packageBuildInfoDataStore
        = new PackageBuildInfoDataStore(_googleComputeEngineConfig);
  }

  void _initListeners() {
    isolateGceLauncherReceivePort.listen((data) {
      if (isCommand(GceLauncherCommand.PACKAGE_BUILD_COMPLETE, data)) {
        Package package = new Package.fromJson(data['message']);
        // TODO: ask datastore if isBuilt is true, then add.
        isBuiltQueue.add(package);
      }
    });
  }

  void callback() {
    if (isBuiltQueue.isNotEmpty) {
      //TODO: Build new index.
      isBuiltQueue.clear();
      _fetchAndBuild().then((_) => new Timer(_timeout, callback));
    } else {
      new Timer(_timeout, callback);
    }
  }

  Future _fetchAndBuild() {
    return _packageBuildInfoDataStore.fetchBuilt()
    .then((List<PackageBuildInfo> packageBuildInfos) {
      Map renderData = {'docsUrls': []};

      renderData['docsUrls'].addAll(packageBuildInfos.map((packageBuildInfo) {
        return {
          "name": packageBuildInfo.name,
          "version": packageBuildInfo.version,
          "url": 'http://www.dartdocs.org/documentation/'
            '${packageBuildInfo.name}/${packageBuildInfo.version}/index.html#'
            '${packageBuildInfo.name}'
        };
      }).toList());

      File dartDocsIndex = new File("dartdocs_index.html");
      dartDocsIndex.writeAsStringSync(_buildDartDocsIndexHtml(renderData));
      _copyDartDocsIndexHtml("dartdocs_index.html");
      dartDocsIndex.deleteSync();
    });
  }

  // TODO: move to library
  String _buildDartDocsIndexHtml(Map renderData, {String dartDocsTemplate:
                                  "dartdocs_index.html.mustache"}) {
    String indexTemplate = new File(dartDocsTemplate).readAsStringSync();
    var template = mustache.parse(indexTemplate);
    var indexHtml = template.renderString(renderData, htmlEscapeValues: false);
    return indexHtml;
  }

  int _copyDartDocsIndexHtml(String dartDocsIndexPath) {
    List<String> args = ['-m', 'cp', '-e', '-c', '-a', 'public-read',
                         dartDocsIndexPath, "gs://www.dartdocs.org/index.html"];
    ProcessResult processResult = Process.runSync('gsutil', args, runInShell: true);
    Logger.root.finest(processResult.stdout);
    Logger.root.severe(processResult.stderr);
    return processResult.exitCode;
  }
}

void main(List<String> args, SendPort replyTo) {
  Logger.root.onRecord.listen((LogRecord record) {
    print("build_index: ${record.message}");
  });

  Logger.root.finest("starting build index");
  Logger.root.finest("args = $args");

  IsolateBuildIndex isolateBuildIndex = new IsolateBuildIndex(replyTo);
  isolateBuildIndex.start();
}