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
  Queue packageInbox = new Queue();
  Queue packageOutbox = new Queue();
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

  start() {
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

  _initListeners() {
    isolateServiceReceivePort.listen((data) {
      print("isolateServiceReceivePort.listen = $data");
      // Create command interface here.
      if (data['command'] == 'packageAdd') {
        Package package = new Package.fromJson(data['message']);
        packageInbox.add(package);
        buildValidationSendPort.send({'command': 'checkPackage',
          'message': package.toJson()});
      }
    });

    buildValidationReceivePort.listen((data) {
      print("buildValidationReceivePort.listen = $data");

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
      print("gceLauncherReceivePort.listen = $data");

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
  print("starting queue service");
  print("args = $args");
  IsolateQueueService isolateQueueService = new IsolateQueueService(replyTo);
  isolateQueueService.start();
}
