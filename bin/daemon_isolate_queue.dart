import 'dart:isolate';
import 'dart:collection';

import 'package:quiver/collection.dart';
import 'package:logging/logging.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

///
/// the queue isolate can spawns a package build validation and
/// a gce launcher
///

class IsolateQueueService {
  Queue<Package> packageInbox = new Queue<Package>();
  Queue<Package> packageOutbox = new Queue<Package>();
  // Queue packageBuildCheck = new Queue();

  Isolate buildValidationIsolate;
  Isolate gceLauncherIsolate;

  ReceivePort isolateServiceReceivePort = new ReceivePort();
  ReceivePort buildValidationReceivePort = new ReceivePort();
  ReceivePort gceLauncherReceivePort = new ReceivePort();

  SendPort buildValidationSendPort;
  SendPort gceLauncherSendPort;
  // reply to the spawner of this isolate.
  SendPort isolateServiceSendPort;

  IsolateQueueService(this.isolateServiceSendPort);

  void start() {
    Isolate.spawnUri(Uri.parse('package_daemon_isolate_build_package_validation.dart'),
                             ['init'], buildValidationReceivePort.sendPort)
                             .then((Isolate buildValidationIsolate) {
      this.buildValidationIsolate = buildValidationIsolate;
      return;
    }).then((_) {
      return Isolate.spawnUri(Uri.parse('package_daemon_isolate_gce_launcher.dart'),
                                     ['init'], gceLauncherReceivePort.sendPort);
    }).then((Isolate gceLauncherIsolate) {
      this.gceLauncherIsolate = gceLauncherIsolate;
      return;
    }).then((_) {
      // Send back a SendPort to communicate over for the spawner
      isolateServiceSendPort.send(isolateServiceReceivePort.sendPort);
      _initListeners();
    });
  }

  void _initListeners() {
    isolateServiceReceivePort.listen((data) {
      // Logger.root.finest("isolateServiceReceivePort.listen = $data");

      // Create command interface here.
      if (data['command'] == 'packageAdd') {
        Package package = new Package.fromJson(data['message']);
        packageInbox.add(package);
        buildValidationSendPort.send({'command': 'checkPackage',
          'message': package.toJson()});
      }
    });

    buildValidationReceivePort.listen((data) {
      // Logger.root.finest("buildValidationReceivePort.listen = $data");

      if (data is SendPort) {
        buildValidationSendPort = data;
        return;
      }

      // Create command interface here.
      if (data['command'] == 'packageRemoveInbox') {
        Package package = new Package.fromJson(data['message']);
        packageInbox.removeWhere((Package p) => p.name == package.name && listsEqual(p.versions, package.versions));
      } else if (data['command'] == 'packageAddOutbox'){
        Package package = new Package.fromJson(data['message']);
        packageInbox.removeWhere((Package p) => p.name == package.name && listsEqual(p.versions, package.versions));
        packageOutbox.add(package);
        gceLauncherSendPort.send({'command': 'buildPackage',
                      'message': package.toJson()});
      }
    });

    gceLauncherReceivePort.listen((data) {
      // Logger.root.finest("gceLauncherReceivePort.listen = $data");

      if (data is SendPort) {
        gceLauncherSendPort = data;
        return;
      }

      // Create command interface here.
      if (data['command'] == 'packageBuildComplete') {
        Package package = new Package.fromJson(data['message']);
        packageOutbox.removeWhere((Package p) => p.name == package.name
            && listsEqual(p.versions, package.versions));
      }
    });
  }
}

void main(List<String> args, SendPort replyTo) {
  Logger.root.onRecord.listen((LogRecord record) {
    print("isolate_queue: ${record.message}");
  });

  Logger.root.finest("starting queue service");
  Logger.root.finest("args = $args");
  IsolateQueueService isolateQueueService = new IsolateQueueService(replyTo);
  isolateQueueService.start();
}
