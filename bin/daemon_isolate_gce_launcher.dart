import "dart:async";
import 'dart:isolate';
import 'dart:collection';

import 'package:quiver/collection.dart';
import 'package:logging/logging.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

final int MAX_GCE_INSTANCES = 3;

class IsolateGceLauncher {
  Duration _timeout = const Duration(seconds: 1);
  Timer _timer;

  Queue<Package> buildQueue = new Queue<Package>();
  Queue<Package> buildingQueue = new Queue<Package>();
  Queue<Package> completedQueue = new Queue<Package>();

  ReceivePort isolateQueueServiceReceivePort = new ReceivePort();

  SendPort isolateQueueServiceSendPort;

  IsolateGceLauncher(this.isolateQueueServiceSendPort);

  void start() {
    isolateQueueServiceSendPort.send(isolateQueueServiceReceivePort.sendPort);
    _initListeners();
    Timer.run(callback);
  }

  void callback() {

    if (buildingQueue.length < MAX_GCE_INSTANCES && buildQueue.isNotEmpty) {
      // TODO: query GCE instead of keeping local counter.
      Package package = buildQueue.removeFirst();
      buildingQueue.add(package);

      Logger.root.finest("buildingQueue.length = ${buildingQueue.length}");
      // TODO: support builder version ranges
      deployDocumentationBuilder(package, package.versions.first);

    } else {
      // TODO: check the current number of build instances on gce
      Logger.root.finest("waiting till available gce instance or buildQueue is empty");
    }

    // TODO: Might be better to check if the `package_build_info.json`
    // file was uploaded.
    completedQueue.addAll(buildingQueue
        .where((p) => !documentationInstanceAlive(p, p.versions.first)).toList());


    while (completedQueue.isNotEmpty) {
      // TODO: only send what has been completed.
      Package completedPackage = completedQueue.removeFirst();

      isolateQueueServiceSendPort.send(
          createMessage(GceLauncherCommand.PACKAGE_BUILD_COMPLETE,
                        completedPackage));

      buildingQueue.removeWhere((p) => p.name == completedPackage.name
          && listsEqual(p.versions, completedPackage.versions));
    }

    // Timer.run(callback);
    // Do not want periodic timer here.
    new Timer(_timeout, callback);
  }

  void _initListeners() {
    isolateQueueServiceReceivePort.listen((data) {
      // Logger.root.finest("isolateQueueServiceReceivePort.listen = $data");

      // TODO: try out hashmaps of functions resolved by command string
      // Create command interface here.
      if (data['command'] == 'buildPackage') {
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
