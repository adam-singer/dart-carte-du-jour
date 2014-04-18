import "dart:async";
import "dart:isolate";

import 'package:logging/logging.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

class IsolateService {
  Duration _timeout;
  Timer _timer;
  ReceivePort port = new ReceivePort();
  Isolate queueIsolate;
  SendPort queueSendPort;

  IsolateService({int seconds: 60}) {
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
    Isolate.spawnUri(Uri.parse('package_daemon_isolate_queue.dart'),
                         ['initQueue'], port.sendPort)
    .then((Isolate queueIsolate) {
      this.queueIsolate = queueIsolate;
      // setup timer now...
      _timer = new Timer.periodic(_timeout, callback);
    });
  }

  void stop() {
    _timer.cancel();
  }

  void callback(Timer timer) {
    Logger.root.fine("callback ${timer}");
    _fetchFirstPage().then((List<Package> packages){
      if (queueSendPort != null) {
        packages.forEach((Package package) =>
            queueSendPort.send({ 'command': 'packageAdd', 'message': package.toJson()}));
      }
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
      // As of now we should only check the latest version of the packages.
      Logger.root.warning("Only checking for the latest version of built packages");
      packages.forEach((Package p) {
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
