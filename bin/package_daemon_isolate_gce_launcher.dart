import "dart:async";
import 'dart:isolate';
import 'dart:collection';

import 'package:quiver/collection.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

final int MAX_GCE_INSTANCES = 3;

class IsolateGceLauncher {

  int _gceInstances = 0;

  Duration _timeout = const Duration(seconds: 1);
  Timer _timer;

  Queue<Package> buildQueue = new Queue<Package>();
  Queue<Package> buildingQueue = new Queue<Package>();
  Queue<Package> completedQueue = new Queue<Package>();

  ReceivePort isolateQueueServiceReceivePort = new ReceivePort();

  SendPort isolateQueueServiceSendPort;

  IsolateGceLauncher(this.isolateQueueServiceSendPort);

  start() {
    isolateQueueServiceSendPort.send(isolateQueueServiceReceivePort.sendPort);
    _initListeners();
//    _timeout = new Duration(seconds: 10);
    // TODO: consider using Timer.run();
//    _timer = new Timer.periodic(_timeout, callback);
    Timer.run(callback);
  }

  void callback() {

    if (_gceInstances < MAX_GCE_INSTANCES && buildQueue.isNotEmpty) {
      // TODO: query GCE instead of keeping local counter.
      Package package = buildQueue.removeFirst();
      buildingQueue.add(package);

      _gceInstances++;
      print("starting new gce instance, _gceInstances = ${_gceInstances}");
      // TODO: support builder version ranges
      deployDocumentationBuilder(package, package.versions.first);

    } else {
      // TODO: check the current number of build instances on gce
      print("waiting till available gce instance or buildQueue is empty");
    }

    // TODO: Might be better to check if the `package_build_info.json`
    // file was uploaded.
    completedQueue.addAll(buildingQueue
        .where((p) => !documentationInstanceAlive(p, p.versions.first)).toList());


    while (completedQueue.isNotEmpty) {
      // TODO: only send what has been completed.
      isolateQueueServiceSendPort.send({'command': 'packageBuildComplete',
        'message': completedQueue.removeFirst().toJson() });
      _gceInstances--;
    }

    // Timer.run(callback);
    // Do not want periodic timer here.
    new Timer(_timeout, callback);
  }

  _initListeners() {
    isolateQueueServiceReceivePort.listen((data) {
      print("isolateQueueServiceReceivePort.listen = $data");

      // TODO: try out hashmaps of functions resolved by command string
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
