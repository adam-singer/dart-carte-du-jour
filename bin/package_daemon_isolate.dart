import "dart:async";
import "dart:isolate";

void main() {
  print("main");
  IsolateService isolateService = new IsolateService();
  isolateService.start();
}

class IsolateService {
  Duration _timeout;
  Timer _timer;
  ReceivePort port = new ReceivePort();
  Isolate queueIsolate;
  SendPort queueSendPort;

  IsolateService({int seconds: 1}) {
    _timeout = new Duration(seconds: seconds);

    // listening on the port keeps the stream open.
    port.listen((onData) {
      // If the remote isolate is sending us back a SendPort
      // then thats how we communicate back.
      if (onData is SendPort) {
        queueSendPort = onData;
      } else if (onData is Map) {
        // If data is a map then expect its a command.
        print("onData = ${onData}");
      }
    });
  }

  start() {
    print("starting server");
    Isolate.spawnUri(Uri.parse('package_daemon_isolate_queue.dart'),
                         ['initQueue'], port.sendPort)
    .then((Isolate queueIsolate) {
      this.queueIsolate = queueIsolate;
      // setup timer now...
      _timer = new Timer.periodic(_timeout, callback);
    });
  }

  stop() {
    _timer.cancel();
  }

  void callback(Timer timer) {
    print("callback ${timer}");
    if (queueSendPort != null) {
      queueSendPort.send({'add': {'package': {'name': 'unittest', 'version': '0.1.1'}}});
    }
  }
}
