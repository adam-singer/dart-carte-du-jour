import 'dart:isolate';

class IsolateGceLauncher {
  ReceivePort isolateQueueServiceReceivePort = new ReceivePort();

  SendPort isolateQueueServiceSendPort;

  IsolateGceLauncher(this.isolateQueueServiceSendPort) {
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
  print("starting gce launcher");
  print("args = $args");

  IsolateGceLauncher isolateGceLauncher = new IsolateGceLauncher(replyTo);
  isolateGceLauncher.start();
}
