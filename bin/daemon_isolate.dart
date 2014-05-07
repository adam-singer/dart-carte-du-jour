import 'dart:io';
import "dart:async";
import "dart:isolate";

import 'package:logging/logging.dart';
import 'package:route/server.dart';
import 'package:route/url_pattern.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

class IsolateService {
  Duration _timeout;
  Timer _timer;
  ReceivePort port = new ReceivePort();
  Isolate queueIsolate;
  SendPort queueSendPort;

  IsolateService({int seconds: 600}) {
    // Default 10 mins to check for new packages.
    _timeout = new Duration(seconds: seconds);

    // listening on the port keeps the stream open.
    port.listen((onData) {
      // If the remote isolate is sending us back a SendPort
      // then thats how we communicate back.
      if (onData is SendPort) {
        queueSendPort = onData;
      } else if (onData is Map) {
        // If data is a map then expect its a command.
        Logger.root.fine("onData = ${onData}");
      }
    });
  }

  void start() {
    Logger.root.fine("starting server");
    Isolate.spawnUri(Uri.parse('daemon_isolate_queue.dart'),
                         ['initQueue'], port.sendPort)
    .then((Isolate queueIsolate) {
      this.queueIsolate = queueIsolate;
      // setup timer now...
      _timer = new Timer.periodic(_timeout, callback);
      // _oneTimeFetchAll();
      // _oneTimeBuildAllVersions();
      _initServer();
    });
  }

  void stop() {
    _timer.cancel();
  }

  void _initServer() {
    final buildUrl = new UrlPattern(r'/build/(.*)');
    final rebuildUrl = new UrlPattern(r'/rebuild/(.*)');
    final buildAllUrl = new UrlPattern(r'/buildAll');
    final rebuildAllUrl = new UrlPattern(r'/rebuildAll');

    void build(HttpRequest req) {
      List<String> args = buildUrl.parse(req.uri.path);
      var packageName = args[0];
      fetchPackage("http://pub.dartlang.org/packages/${packageName}.json")
      .then((Package package) {
        queueSendPort.send(createMessage(MainIsolateCommand.PACKAGE_ADD, package));
        req.response.write('queue ${package.toString()}');
        req.response.close();
      }).catchError((error) => req.response.close());
    }

    // Does not check datastore if package is build. Just rebuild the package.
    void rebuild(HttpRequest req) {
      // TODO: dup code, factor out.
      List<String> args = rebuildUrl.parse(req.uri.path);
      var packageName = args[0];
      fetchPackage("http://pub.dartlang.org/packages/${packageName}.json")
      .then((Package package) {
        queueSendPort.send(createMessage(MainIsolateCommand.PACKAGE_REBUILD, package));
        req.response.write('rebuild ${package.toString()}');
        req.response.close();
      }).catchError((error) => req.response.close());
    }

    void buildAll(HttpRequest req) {
      _oneTimeBuildAllVersions();
      req.response.write("Queueing all packages and versions");
      req.response.close();
    }

    void rebuildAll(HttpRequest req) {
      _oneTimeBuildAllVersions(rebuild: true);
      req.response.write("Rebuilding all packages and versions");
      req.response.close();
    }

    // Callback to handle illegal urls.
    void serveNotFound(HttpRequest req) {
      req.response.statusCode = HttpStatus.NOT_FOUND;
      req.response.write('Not found');
      req.response.close();
    }

    HttpServer.bind(InternetAddress.LOOPBACK_IP_V4, 8889).then((server) {
      var router = new Router(server)
        // Associate callbacks with URLs.
        ..serve(buildUrl, method: 'GET').listen(build)
        ..serve(rebuildUrl, method: 'GET').listen(rebuild)
        ..serve(buildAllUrl, method: 'GET').listen(buildAll)
        ..serve(rebuildAllUrl, method: 'GET').listen(rebuildAll)
        ..defaultStream.listen(serveNotFound);
    });
  }

  void _oneTimeBuildAllVersions({bool rebuild: false}) {
    var duration = new Duration(seconds: 10);
    fetchAllPackage().then((List<Package> packages) {
      void callback() {

        if (queueSendPort != null) {
           // Remove null packages.
           Logger.root.warning("Found ${packages.where((e) => e == null).length} null packages");
           // packages is a fixed length list.
           packages = packages.toList();
           packages.removeWhere((e) => e == null);

           // Queue all versions
           Logger.root.warning("Sorting all versions");
           packages.forEach((Package p) => p.versions.sort());

           packages.forEach((Package package) {
             if (rebuild) {
               queueSendPort.send(createMessage(MainIsolateCommand.PACKAGE_REBUILD, package));
             } else {
               queueSendPort.send(createMessage(MainIsolateCommand.PACKAGE_ADD, package));
             }
           });
           return;
         }

        new Future.delayed(duration, callback);
      }

      callback();
    });
  }

  void _oneTimeFetchAll() {
    var duration = new Duration(seconds: 10);
    fetchAllPackage().then((List<Package> packages) {
      void callback() {

        if (queueSendPort != null) {
           // Remove null packages.
           Logger.root.warning("Found ${packages.where((e) => e == null).length} null packages");
           // packages is a fixed length list.
           packages = packages.toList();
           packages.removeWhere((e) => e == null);

           // As of now we should only check the latest version of the packages.
           Logger.root.warning("Only checking for the latest version of built packages");
           packages.forEach((Package p) {
              p.versions.sort();
              p.versions = [p.versions.last];
           });

           packages.forEach((Package package) =>
               queueSendPort.send(createMessage(MainIsolateCommand.PACKAGE_ADD, package)));
           return;
         }

        new Future.delayed(duration, callback);
      }

      callback();
    });
  }

  void callback(Timer timer) {
    Logger.root.fine("callback ${timer}");
    _fetchFirstPage().then((List<Package> packages){
      if (queueSendPort != null) {
        packages.forEach((Package package) {
          package.versions.sort();
          package.versions = [package.versions.last];
          queueSendPort.send(createMessage(MainIsolateCommand.PACKAGE_ADD, package));
        });
      }
    }).catchError((error) {
      Logger.root.severe("fetching packages error: $error");
    });
  }

  Future<List<Package>> _fetchFirstPage() {
    return fetchPackages()
    .then((PubPackages pubPackages) {
      Logger.root.fine("Pub packages fetched");
      return pubPackages.packages.map(fetchPackage).toList();
    }).then((List<Future<Package>> packages) {
      Logger.root.fine("Waiting for individual packages to be fetched");
      return Future.wait(packages);
    }).then((List<Package> packages) {
      Logger.root.fine("All packages fetched");

      // Remove null packages.
      Logger.root.warning("Found ${packages.where((e) => e == null).length} null packages");
      // packages is a fixed length list.
      packages = packages.toList();
      packages.removeWhere((e) => e == null);

      // As of now we should only check the latest version of the packages.
      Logger.root.warning("Only checking for the latest version of built packages");
      packages.forEach((Package p) {
        p.versions.sort();
        p.versions = [p.versions.last];
      });
      return packages;
    });
  }
}

void main() {
  Logger.root.onRecord.listen((LogRecord record) {
    print("isolate_main: ${record.message}");
  });

  IsolateService isolateService = new IsolateService();
  isolateService.start();
}
