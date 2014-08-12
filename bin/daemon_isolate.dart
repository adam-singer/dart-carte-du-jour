import 'dart:io';
import "dart:async";
import "dart:isolate";

import 'package:logging/logging.dart';
import 'package:route/server.dart';
import 'package:route/url_pattern.dart';
import 'package:args/args.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

class IsolateService {
  Duration _timeout;
  // Pausing the fetching of first page.
  bool _isPaused = false;
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
    final buildFirstPageUrl = new UrlPattern(r'/buildFirstPage');
    final isPausedUrl = new UrlPattern(r'/isPaused');
    final pauseUrl = new UrlPattern(r'/pause');
    final healthCheckUrl = new UrlPattern(r'/health');
    final SERVER_PORT = 8889;

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

    // queue all packages for building, if build already exists do not rebuild.
    void buildAll(HttpRequest req) {
      _oneTimeBuildAllVersions();
      req.response.write("Queueing all packages and versions");
      req.response.close();
    }

    // force rebuild of all packages
    void rebuildAll(HttpRequest req) {
      _oneTimeBuildAllVersions(rebuild: true);
      req.response.write("Rebuilding all packages and versions");
      req.response.close();
    }

    // builds the latest versions of the first page
    void buildFirstPage(HttpRequest req) {
      callback(null);
      req.response.write("Building first page");
      req.response.close();
    }
    
    void pauseBuildingStatus(HttpRequest req) {
      req.response.statusCode = HttpStatus.OK;
      req.response.writeln(_isPaused);
      req.response.close();
    }
    
    void pauseBuilding(HttpRequest req) {
      req.response.statusCode = HttpStatus.OK;
      _isPaused = !_isPaused;
      req.response.writeln(_isPaused);
      req.response.close();
    }

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
      var router = new Router(server)
        // Associate callbacks with URLs.
        ..serve(buildUrl, method: 'GET').listen(build)
        ..serve(rebuildUrl, method: 'GET').listen(rebuild)
        ..serve(buildAllUrl, method: 'GET').listen(buildAll)
        ..serve(rebuildAllUrl, method: 'GET').listen(rebuildAll)
        ..serve(buildFirstPageUrl, method: 'GET').listen(buildFirstPage)
        ..serve(isPausedUrl, method: 'GET').listen(pauseBuildingStatus)
        ..serve(pauseUrl, method: 'GET').listen(pauseBuilding)
        ..serve(healthCheckUrl, method: 'GET').listen(health)
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
    }).catchError((error) {
      Logger.root.severe("one time build of all packages error: $error");
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
    }).catchError((error) {
      Logger.root.severe("one time fetch all packages error: $error");
    });
  }

  void callback(Timer _) {
    if (_isPaused) {
      return;
    }
    
    Logger.root.fine("fetching first page");
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
      // packages is a fixed length list.
      packages = packages.toList();
      packages.removeWhere((e) => e == null);

      // As of now we should only check the latest version of the packages.
      Logger.root.finest("Only checking for the latest version of built packages");
      packages.forEach((Package p) {
        p.versions.sort();
        p.versions = [p.versions.last];
      });
      return packages;
    });
  }
}

void _printUsage(ArgParser parser) {
  print('usage: dart bin/daemon_isolate.dart <options>');
  print('');
  print('where <options> is one or more of:');
  print(parser.getUsage().replaceAll('\n\n', '\n'));
  exit(1);
}

ArgParser _createArgsParser() {
  ArgParser parser = new ArgParser();
    parser.addFlag('help',
        abbr: 'h',
        negatable: false,
        help: 'show command help',
        callback: (help) {
          if (help) {
            _printUsage(parser);
          }
        });

    parser.addFlag('verbose', abbr: 'v',
        help: 'Output more logging information.', negatable: false,
        callback: (verbose) {
          if (verbose) {
            Logger.root.level = Level.FINEST;
          }
        });

    return parser;
}

void main(List<String> args) {
  Logger.root.onRecord.listen((LogRecord record) {
    print("daemon_isolate: ${record.message}");
  });

  ArgParser parser = _createArgsParser();
  ArgResults results = parser.parse(args);

  IsolateService isolateService = new IsolateService();
  isolateService.start();
}
