library daemon_isolate_build_latest_index;

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
const int TIMEOUT_CALLBACK_BETWEEN_PACKAGE_SECONDS = 5;
final String COFNIG_FILE = "bin/config.json";

class IsolateBuildLatestIndex {
  Duration _timeout = const Duration(seconds: TIMEOUT_CALLBACK_SECONDS);
  Duration _timeoutBetweenPackageBuild = 
      const Duration(seconds: TIMEOUT_CALLBACK_BETWEEN_PACKAGE_SECONDS);
  
  PackageBuildInfoDataStore _packageBuildInfoDataStore;
  GoogleComputeEngineConfig _googleComputeEngineConfig;
  Queue<Package> buildQueue = new Queue<Package>();
  ReceivePort isolateGceLauncherReceivePort = new ReceivePort();
  SendPort isolateGceLauncherSendPort;
  IsolateBuildLatestIndex(this.isolateGceLauncherSendPort);
  
  void start() {
    isolateGceLauncherSendPort.send(isolateGceLauncherReceivePort.sendPort);
    _initListeners();
    _initDatastore();
    _initServer();
    Timer.run(callback);
  }
  
  void callback() { 
    if (buildQueue.isNotEmpty) {
      Package package = buildQueue.removeFirst();
      _buildLatestIndex(package.name).then((_) => 
          new Timer(_timeoutBetweenPackageBuild, callback));
    } else {
      new Timer(_timeout, callback);
    }
  }
  
  void _addPackage(Package package) {
    // If the package is not already enqueued then queue it.
    if (!buildQueue.any((e) => e.name == package.name)) {
      buildQueue.add(package);
    }
  }
  
  void _addAllPackages(List<Package> packages) =>
    packages.forEach((Package package) => _addPackage(package));

  void _initListeners() {
    isolateGceLauncherReceivePort.listen((data) {
      if (isCommand(GceLauncherCommand.PACKAGE_BUILD_COMPLETE, data)) {
        Package package = new Package.fromJson(data['message']);
        _addPackage(package);
      }    
    });
  }
  
  // TODO: DRY
  void _initDatastore() {
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
  
  Future _buildLatestIndex(String name) {
     return _packageBuildInfoDataStore.fetchVersions(name).then((List<PackageBuildInfo> packageBuildInfos) { 
       if (packageBuildInfos.isEmpty) {
         return;
       }
       
       List<Version> versions = new List<Version>();
       versions.addAll(packageBuildInfos
           .map((PackageBuildInfo package) => package.version).toList());
       versions.sort();
       Version latest = versions.last;
       String latestIndexPath = _latestIndexPath(name, latest);
       String latestStoragePath = _latestStoragePath(name);
       Map renderData = {'url': latestIndexPath};
       String latestIndexHtml = _buildLatestIndexHmtl(renderData);
       String latestFileName = _latestFileName(name);
       File latestIndexFile = new File(latestFileName);
       latestIndexFile.writeAsStringSync(latestIndexHtml);
       _copyLatestIndex(latestFileName, latestStoragePath);
       latestIndexFile.deleteSync();
       Logger.root.finest("built $name $latest $latestStoragePath");
     }).catchError((error) {
       Logger.root.severe("Not able to build latest for $name");
       Logger.root.severe("error = ${error.toString()}");
     });
  }
  
  String _latestIndexPath(String name, Version version) => 
      "${PACKAGE_HTTP_ROOT}/${name}/${version.toString()}/index.html";
  
  String _latestStoragePath(String name) => 
      "${PACKAGE_STORAGE_ROOT}/${name}/latest/index.html";
      
  String _latestFileName(String name) => "dartdocs_${name}_index.html";
  
  // renderData = {'url': 'http://www.dartdocs.org/documentation/unittest/0.9.3'}
  String _buildLatestIndexHmtl(Map renderData, {String dartDocsTemplate: "bin/dartdocs_latest_index.html.mustache"}) {
    String indexTemplate = new File(dartDocsTemplate).readAsStringSync();
    var template = mustache.parse(indexTemplate);
    var indexHtml = template.renderString(renderData, htmlEscapeValues: false);
    return indexHtml;
  }
  
  // copy the latest index.html file
  int _copyLatestIndex(String filePath, String destinationPath) {
    List<String> args = ['-m', 'cp',
                         '-e',
                         '-c',
                         '-z', COMPRESS_FILE_TYPES,
                         '-a', 'public-read',
                         filePath, destinationPath];
    ProcessResult processResult = Process.runSync('gsutil', args, runInShell: true);
    stdout.write(processResult.stdout);
    stderr.write(processResult.stderr);
    return processResult.exitCode;
  }
  
  void _initServer() {
    // TODO: have a handler that sets the latest?
    final buildPackageLatestIndexUrl = new UrlPattern(r'/build/(.*)');    
    final buildAllPackageLatestIndexUrl =  new UrlPattern(r'/buildAll');
    final healthCheckUrl = new UrlPattern(r'/health');
    final SERVER_PORT = 8884;
    
    // Callback to handle illegal urls.
    void serveNotFound(HttpRequest req) {
      req.response.statusCode = HttpStatus.NOT_FOUND;
      req.response.write('Not found');
      req.response.close();
    }
    
    void build(HttpRequest req) {
      req.response.statusCode = HttpStatus.OK;
      List<String> args = buildPackageLatestIndexUrl.parse(req.uri.path);
      String packageName = args[0];
      Package package = new Package(packageName, []);
      _addPackage(package);
      req.response.write('queue $packageName');
      req.response.close();
    }
    
    void buildAll(HttpRequest req) {
      req.response.statusCode = HttpStatus.OK;
      fetchAllPackage().then(_addAllPackages);
      req.response.write('Queued all packages to redirect to latest version');
      req.response.close();
    }
    
    void health(HttpRequest req) {
      req.response.statusCode = HttpStatus.OK;
      req.response.writeln('All systems a go');
      req.response.writeln('buildQueue: ');
      buildQueue.forEach((e) => req.response.writeln(e.toString()));
      req.response.close();
    }
    
    HttpServer.bind(InternetAddress.LOOPBACK_IP_V4, SERVER_PORT).then((server) {
      var router = new Router(server)
        // Associate callbacks with URLs.
        ..serve(buildPackageLatestIndexUrl, method: 'GET').listen(build)
        ..serve(buildAllPackageLatestIndexUrl, method: 'GET').listen(buildAll)
        ..serve(healthCheckUrl, method: 'GET').listen(health)
        ..defaultStream.listen(serveNotFound);
    });
  }
}

void main(List<String> args, SendPort replyTo) {
  Logger.root.onRecord.listen((LogRecord record) {
    print("build_latest_index: ${record.message}");
  });

  Logger.root.finest("starting build latest index");
  Logger.root.finest("args = $args");

  IsolateBuildLatestIndex isolateBuildLatestIndex = new IsolateBuildLatestIndex(replyTo);
  isolateBuildLatestIndex.start();
}