import 'dart:isolate';

import 'package:logging/logging.dart';

import 'package:dart_carte_du_jour/carte_de_jour.dart';

class IsolateBuildPackageValidation {
  ReceivePort isolateQueueServiceReceivePort = new ReceivePort();

  SendPort isolateQueueServiceSendPort;

  IsolateBuildPackageValidation(this.isolateQueueServiceSendPort);

  void start() {
    isolateQueueServiceSendPort.send(isolateQueueServiceReceivePort.sendPort);
    _initListeners();
  }

  void _initListeners() {
    isolateQueueServiceReceivePort.listen((data) {
      // Create command interface here.
      if (isCommand(QueueCommand.CHECK_PACKAGE, data)) {
        Package package = new Package.fromJson(data['message']);
        package.checkPackageIsBuilt(package.versions.last)
        .then((PackageBuildInfo packageBuildInfo) {
          if (packageBuildInfo == null) {
            // Package has never been built.
            isolateQueueServiceSendPort.send(createMessage(PackageValidationCommand.PACKAGE_ADD_OUTBOX, package));
            return;
          }

          if (!packageBuildInfo.isBuilt) {
            // Package cannot be built. isBuilt == false is considered a
            // blacklisted package.
            Logger.root.fine("blacklisted: ${packageBuildInfo.toString()}");
          }
        });
      }
    });
  }
}

void main(List<String> args, SendPort replyTo) {
  Logger.root.onRecord.listen((LogRecord record) {
    print("build_package: ${record.message}");
  });

  Logger.root.finest("starting build package validation");
  Logger.root.finest("args = $args");
  Logger.root.finest("replyTo = $replyTo");

  IsolateBuildPackageValidation isolateBuildPackageValidation = new IsolateBuildPackageValidation(replyTo);
  isolateBuildPackageValidation.start();
}
