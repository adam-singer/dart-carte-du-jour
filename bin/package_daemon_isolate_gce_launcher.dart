import "dart:async";
import 'dart:isolate';
import 'dart:collection';

import 'package:quiver/collection.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

final int MAX_GCE_INSTANCES = 10;

class IsolateGceLauncher {

  int _gceInstances = 0;

  Duration _timeout;
  Timer _timer;

  Queue buildQueue = new Queue();
  ReceivePort isolateQueueServiceReceivePort = new ReceivePort();

  SendPort isolateQueueServiceSendPort;

  IsolateGceLauncher(this.isolateQueueServiceSendPort);

  start() {
    isolateQueueServiceSendPort.send(isolateQueueServiceReceivePort.sendPort);
    _initListeners();
    _timeout = new Duration(seconds: 1);
    // TODO: consider using Timer.run();
    _timer = new Timer.periodic(_timeout, callback);
  }

  void callback(Timer timer) {

    if (_gceInstances < MAX_GCE_INSTANCES && buildQueue.isNotEmpty) {
      // TODO: query GCE instead of keeping local counter.
      _gceInstances++;
      print("starting new gce instance, _gceInstances = ${_gceInstances}");

      // Replace with deployDocumentationBuilder
      new Future.delayed(new Duration(seconds:100), () {
        print('a gce instance has completed, _gceInstances = ${_gceInstances}');
        _gceInstances--;
        // TODO: on complete isolateQueueServiceSendPort.send("completed package");
      });
    } else {
      // TODO: check the current number of build instances on gce
      print("waiting till available gce instance or buildQueue is empty");
    }

  }

  _initListeners() {
    isolateQueueServiceReceivePort.listen((data) {
      print("isolateQueueServiceReceivePort.listen = $data");

      // Create command interface here.
      if (data['command'] == 'buildPackage') {
        Package package = new Package.fromJson(data['message']);
        bool isInQueue = buildQueue.any((Package p) =>
                  p.name == package.name && listsEqual(p.versions, package.versions));

        if (!isInQueue) {
          buildQueue.add(package);
        }

        print("buildQueue = ${buildQueue.toList()}");
        print("buildQueue.length = ${buildQueue.length}");
      }
    });
  }
}

void main(List<String> args, SendPort replyTo) {
  print("starting gce launcher");
  print("args = $args");

  IsolateGceLauncher isolateGceLauncher = new IsolateGceLauncher(replyTo);
  isolateGceLauncher.start();
}
