import "dart:io";
import "dart:async";
import 'dart:isolate';
import 'dart:collection';
import "dart:convert";

import 'package:logging/logging.dart';
import 'package:route/server.dart';
import 'package:route/url_pattern.dart';
import 'package:mustache/mustache.dart' as mustache;

import 'package:dart_carte_du_jour/carte_de_jour.dart';

const int TIMEOUT_CALLBACK_SECONDS = 60;
final String FAILED_URL = "http://www.dartdocs.org/failed/index.html";
final String COFNIG_FILE = "bin/config.json";

class IsolateBuildIndex {
  Duration _timeout = const Duration(seconds: TIMEOUT_CALLBACK_SECONDS);

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
    _initServer();
    Timer.run(callback);
  }

  void stop() {}

  void _initDatastore() {
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
      isBuiltQueue.clear();
      _fetchAndBuild().then((_) => new Timer(_timeout, callback));
    } else {
      new Timer(_timeout, callback);
    }
  }

  // TODO: consider building history here.
  Future _fetchAndBuild() {
    return _packageBuildInfoDataStore.fetchBuilt()
    .then((List<PackageBuildInfo> packageBuildInfos) {
      Map renderData = {'packages': []};
      Map packages = {};

      packageBuildInfos.forEach((packageBuildInfo) {
        final package = packages.putIfAbsent(packageBuildInfo.name, () => {
          "name": packageBuildInfo.name,
          "versions": [],
        });
        package['versions'].add(packageBuildInfo.version);
      });

      // Sort versions
      packages.keys.forEach((String name) {
        packages[name]["versions"].sort();
        packages[name]["versions"] = packages[name]["versions"]
        .reversed
        .map((Version version) => {
          "version": version.toString(),
          "url": 'http://www.dartdocs.org/documentation/'
          '${name}/${version.toString()}/index.html#${name}'
        }).toList();
      });

      renderData['packages'].addAll(packages.values);
      renderData['failedurl'] = FAILED_URL;

      File dartDocsIndex = new File("dartdocs_index.html");
      dartDocsIndex.writeAsStringSync(_buildDartDocsIndexHtml(renderData));
      _copyDartDocsIndexHtml("dartdocs_index.html");
      dartDocsIndex.deleteSync();

      // Generate index.json
      String indexJson = JSON.encode(renderData);
      File dartDocsIndexJson = new File("dartdocs_index.json");
      dartDocsIndexJson.writeAsStringSync(indexJson);
      _copyDartDocsRoot("dartdocs_index.json", "index.json");
      dartDocsIndexJson.deleteSync();

      return _packageBuildInfoDataStore.fetchBuilt(false);
    }).then((List<PackageBuildInfo> packageBuildInfos) {
      // TODO: DRY
      Map renderData = {'docsUrls': []};
      renderData['docsUrls'].addAll(packageBuildInfos.map((packageBuildInfo) {
        Uri httpBuildLog;

        if (packageBuildInfo.buildLog != null && packageBuildInfo.buildLog.isNotEmpty) {
          Uri gsBuildLog = Uri.parse(packageBuildInfo.buildLog);
          httpBuildLog = new Uri.http(gsBuildLog.host, gsBuildLog.path);
        } else {
          httpBuildLog = new Uri.http("www.dartdocs.org", "/failed/notfound.html");
        }

        return {
          "name": packageBuildInfo.name,
          "version": packageBuildInfo.version,
          "url": httpBuildLog.toString()
        };
      }).toList());

      File dartDocsIndex = new File("dartdocs_failed_index.html");
      dartDocsIndex.writeAsStringSync(_buildDartDocsFailedIndexHtml(renderData));
      _copyDartDocsFailedIndexHtml("dartdocs_failed_index.html");
      dartDocsIndex.deleteSync();

      return;
      // Generate failed.json
//      String failedJson = JSON.encode(renderData);
//      File dartDocsFailedJson = new File("dartdocs_failed.json");
//      dartDocsFailedJson.writeAsStringSync(failedJson);
//      _copyDartDocsRoot("dartdocs_failed.json", "failed.json");
//      dartDocsFailedJson.deleteSync();
    }).then((_) {
      return _packageBuildInfoDataStore.fetchHistory(200);
    }).then((List<PackageBuildInfo> packageBuildInfos) {
      Map renderData = {'packages': []};
      renderData['packages'].addAll(packageBuildInfos.map((PackageBuildInfo packageBuildInfo) {

        Uri httpBuildLog;

        if (packageBuildInfo.buildLog != null && packageBuildInfo.buildLog.isNotEmpty) {
          Uri gsBuildLog = Uri.parse(packageBuildInfo.buildLog);
          httpBuildLog = new Uri.http(gsBuildLog.host, gsBuildLog.path);
        } else {
          httpBuildLog = new Uri.http("www.dartdocs.org", "/failed/notfound.html");
        }

        return {
          "name": packageBuildInfo.name,
          "version": packageBuildInfo.version.toString(),
          "timestamp": packageBuildInfo.datetime,
          "isBuilt": packageBuildInfo.isBuilt,
          "buildLogUrl": httpBuildLog.toString()
        };
      }).toList());
      File historyIndexFile = new File("dartdocs_history_index.html");
      historyIndexFile.writeAsStringSync(_buildDartDocsHistoryIndexHtml(renderData));
      _copyDartDocsHistoryIndexHtml("dartdocs_history_index.html");
      historyIndexFile.deleteSync();
    }).catchError((error) {
        Logger.root.severe("fetch and build failed on building index pages: $error");
    });
  }

  // TODO: DRY
  String _buildDartDocsFailedIndexHtml(Map renderData, {String dartDocsTemplate:
                                  "bin/dartdocs_failed_index.html.mustache"}) {
    String indexTemplate = new File(dartDocsTemplate).readAsStringSync();
    var template = mustache.parse(indexTemplate);
    var indexHtml = template.renderString(renderData, htmlEscapeValues: false);
    return indexHtml;
  }

  // TODO: DRY
  String _buildDartDocsHistoryIndexHtml(Map renderData, {String dartDocsTemplate:
                                  "bin/dartdocs_history_index.html.mustache"}) {
    String indexTemplate = new File(dartDocsTemplate).readAsStringSync();
    var template = mustache.parse(indexTemplate);
    var indexHtml = template.renderString(renderData, htmlEscapeValues: false);
    return indexHtml;
  }


  // TODO: DRY
  int _copyDartDocsRoot(String filePath, String destinationPath) {
    List<String> args = ['-m', 'cp',
                         '-e',
                         '-c',
                         '-z', COMPRESS_FILE_TYPES,
                         '-a', 'public-read',
                         filePath, "gs://www.dartdocs.org/${filePath}"];
    ProcessResult processResult = Process.runSync('gsutil', args, runInShell: true);
    stdout.write(processResult.stdout);
    stderr.write(processResult.stderr);
    return processResult.exitCode;
  }

  // TODO: DRY
  int _copyDartDocsFailedIndexHtml(String dartDocsIndexPath) {
    List<String> args = ['-m', 'cp',
                         '-e',
                         '-c',
                         '-z', COMPRESS_FILE_TYPES,
                         '-a', 'public-read',
                         dartDocsIndexPath, "gs://www.dartdocs.org/failed/index.html"];
    ProcessResult processResult = Process.runSync('gsutil', args, runInShell: true);
    stdout.write(processResult.stdout);
    stderr.write(processResult.stderr);
    return processResult.exitCode;
  }

  // TODO: DRY
  int _copyDartDocsHistoryIndexHtml(String dartDocsIndexPath) {
    List<String> args = ['-m', 'cp',
                         '-e',
                         '-c',
                         '-z', COMPRESS_FILE_TYPES,
                         '-a', 'public-read',
                         dartDocsIndexPath, "gs://www.dartdocs.org/history/index.html"];
    ProcessResult processResult = Process.runSync('gsutil', args, runInShell: true);
    stdout.write(processResult.stdout);
    stderr.write(processResult.stderr);
    return processResult.exitCode;
  }

  // TODO: move to library
  String _buildDartDocsIndexHtml(Map renderData, {String dartDocsTemplate:
                                  "bin/dartdocs_index.html.mustache"}) {
    String indexTemplate = new File(dartDocsTemplate).readAsStringSync();
    var template = mustache.parse(indexTemplate);
    var indexHtml = template.renderString(renderData, htmlEscapeValues: false);
    return indexHtml;
  }

  int _copyDartDocsIndexHtml(String dartDocsIndexPath) {
    List<String> args = ['-m', 'cp',
                         '-e',
                         '-c',
                         '-z', COMPRESS_FILE_TYPES,
                         '-a', 'public-read',
                         dartDocsIndexPath, "gs://www.dartdocs.org/index.html"];
    ProcessResult processResult = Process.runSync('gsutil', args, runInShell: true);
    Logger.root.finest(processResult.stdout);
    Logger.root.severe(processResult.stderr);
    return processResult.exitCode;
  }

  void _initServer() {
    final buildIndexHtmlUrl = new UrlPattern(r'/buildIndexHtml');
    final healthCheckUrl = new UrlPattern(r'/health');
    final SERVER_PORT = 8887;

    void buildIndexHtml(HttpRequest req) {
      _fetchAndBuild();
      req.response.write('Rebuilding index html');
      req.response.close();
    }

    void health(HttpRequest req) {
      req.response.statusCode = HttpStatus.OK;
      req.response.writeln('All systems a go');
      req.response.writeln('isBuiltQueue: ');
      isBuiltQueue.forEach((e) => req.response.writeln(e.toString()));
      req.response.close();
    }

    // Callback to handle illegal urls.
    void serveNotFound(HttpRequest req) {
      req.response.statusCode = HttpStatus.NOT_FOUND;
      req.response.write('Not found');
      req.response.close();
    }

    HttpServer.bind(InternetAddress.LOOPBACK_IP_V4, SERVER_PORT).then((server) {
      var router = new Router(server)
        // Associate callbacks with URLs.
        ..serve(buildIndexHtmlUrl, method: 'GET').listen(buildIndexHtml)
        ..serve(healthCheckUrl, method: 'GET').listen(health)
        ..defaultStream.listen(serveNotFound);
    });
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