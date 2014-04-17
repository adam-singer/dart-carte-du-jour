import 'dart:isolate';

import 'package:logging/logging.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

class IsolateBuildPackageValidation {
  ReceivePort isolateQueueServiceReceivePort = new ReceivePort();

  SendPort isolateQueueServiceSendPort;

  IsolateBuildPackageValidation(this.isolateQueueServiceSendPort);

  start() {
    isolateQueueServiceSendPort.send(isolateQueueServiceReceivePort.sendPort);
    _initListeners();
  }

  _initListeners() {
    isolateQueueServiceReceivePort.listen((data) {
      print("isolateQueueServiceReceivePort.listen = $data");

      // Create command interface here.
      if (data['command'] == 'checkPackage') {
        Package package = new Package.fromJson(data['message']);
        checkPackageIsBuilt(package, package.versions.last)
        .then((PackageBuildInfo packageBuildInfo) {
          Map data = {'message': package.toJson()};
          if (packageBuildInfo.isBuilt) {
            // Remove it from the packageInbox
            data['command'] = 'packageRemoveInbox';
          } else {
            // Place it on the packageOutbox
            data['command'] = 'packageAddOutbox';
          }

          isolateQueueServiceSendPort.send(data);
        });
      }
    });
  }
}

void main(List<String> args, SendPort replyTo) {
  print("starting build package validation");
  print("args = $args");
  print("replyTo = $replyTo");

  IsolateBuildPackageValidation isolateBuildPackageValidation = new IsolateBuildPackageValidation(replyTo);
  isolateBuildPackageValidation.start();
}
