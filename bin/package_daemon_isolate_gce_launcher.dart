import 'dart:isolate';

ReceivePort port = new ReceivePort();

void main(List<String> args, SendPort replyTo) {
  print("starting gce launcher");

  port.listen((data) {
    print("port.listen = $data");

    // Create command interface here.
  });

  // Send back a SendPort to communicate over.
  replyTo.send(port.sendPort);
}