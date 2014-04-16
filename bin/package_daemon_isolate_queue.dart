import 'dart:isolate';
import 'dart:collection';

///
/// the queue isolate can spawns a package build validation and
/// a gce launcher
///

class IsolateQueueService {
  Queue packageInbox = new Queue();
  Queue packageOutbox = new Queue();
  Queue packageBuildCheck = new Queue();

  Isolate buildValidationIsolate;
  Isolate gceLauncherIsolate;

  ReceivePort isolateServiceReceivePort = new ReceivePort();
  ReceivePort buildValidationReceivePort = new ReceivePort();
  ReceivePort gceLauncherReceivePort = new ReceivePort();

  SendPort buildValidationSendPort;
  SendPort gceLauncherSendPort;
  // reply to the spawner of this isolate.
  SendPort isolateServiceSendPort;

  IsolateQueueService(this.isolateServiceSendPort) {
    isolateServiceReceivePort.listen((data) {
      print("isolateServiceReceivePort.listen = $data");

      // Create command interface here.
    });

    buildValidationReceivePort.listen((data) {
      print("buildValidationReceivePort.listen = $data");

      // Create command interface here.
    });

    gceLauncherReceivePort.listen((data) {
      print("gceLauncherReceivePort.listen = $data");

      // Create command interface here.
    });

  }

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
    });
  }
}

void main(List<String> args, SendPort replyTo) {
  print("starting queue service");
  print("args = $args");
  IsolateQueueService isolateQueueService = new IsolateQueueService(replyTo);
  isolateQueueService.start();
}