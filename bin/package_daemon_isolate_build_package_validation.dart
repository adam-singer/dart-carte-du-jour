import 'dart:isolate';

class IsolateBuildPackageValidation {
  ReceivePort isolateQueueServiceReceivePort = new ReceivePort();

  SendPort isolateQueueServiceSendPort;

  IsolateBuildPackageValidation(this.isolateQueueServiceSendPort) {
    isolateQueueServiceReceivePort.listen((data) {
      print("isolateQueueServiceReceivePort.listen = $data");

      // Create command interface here.
    });

  }

  start() {
    isolateQueueServiceSendPort.send(isolateQueueServiceReceivePort.sendPort);
  }
}

void main(List<String> args, SendPort replyTo) {
  print("starting build package validation");
  print("args = $args");

  IsolateBuildPackageValidation isolateBuildPackageValidation = new IsolateBuildPackageValidation(replyTo);
  isolateBuildPackageValidation.start();
}
