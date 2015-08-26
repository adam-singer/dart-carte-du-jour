#!/usr/bin/env dart

import 'package:unscripted/unscripted.dart';

main(List<String> args) => new Script(DaemonCommands).execute(args);

class DaemonCommands {
  final String configPath;

  @Command(
      help: 'Manages a server',
      plugins: const [const Completion()])
  DaemonCommands({this.configPath: 'config.json'});

  @SubCommand(help: 'cat build log')
  catlog(@Option(help: 'instance id') String id) {
    print("carte_catlog");
  }

  @SubCommand(help: 'cat config file')
  catconfig(@Option(help: 'instance id') String id) {
    print("carte_catconfig");
  }

  @SubCommand(help: 'list running gce instances')
  list() {
    print("carte_list");
  }

  @SubCommand(help: 'remotely restarts daemon isolate')
  restartDaemonIsolate() {
    print("restart_daemon_isolate");
  }

  @SubCommand(help: '')
  startDaemonIsolate() {
    print("startDaemonIsolate");
  }

  @SubCommand(help: '')
  stopDaemonIsolate() {
    print("stopDaemonIsolate");
  }

  @SubCommand(help: '')
  tailDaemonIsolate() {
    print("tailDaemonIsolate");
  }

  // TODO(adam): non daemon isolate instances are not public anymore.
  // Not valid command anymore.
  @SubCommand(help: '')
  tailInstance() {
    print("tailInstance");
  }

  @SubCommand(help: 'package to build')
  buildPackage(String packageName) {
    print("buildPackage");
  }

  @SubCommand(help: 'package to rebuild')
  rebuildPackage(String packageName) {
    print("rebuildPackage");
  }

  @SubCommand(help: 'build all packages')
  buildallPackages() {
    print("buildallPackages");
  }

  @SubCommand(help: 'rebuild all packages')
  rebuildallPackages() {
    print("rebuildallPackages");
  }

  @SubCommand(help: 'build the first page of packages on pub')
  buildFirstPage() {
    print("buildFirstPage");
  }

  @SubCommand(help: 'build static html pages index, 404, history and failure')
  buildIndexHtml() {
    print("buildIndexHtml");
  }

  @SubCommand(help: 'build specific package with version')
  buildPackageVersion(String packageName, String packageVersion) {
    print("buildPackageVersion");
  }

  // TODO(adam): all the four commands below can be merged into single command
  // with two flags. -v for verbose output and -l for localhost.

  // TODO(adam): healthChecks, remoteHealthChecks, localStatus can merge to the -l flag
  @SubCommand(help: 'Get the simple status of daemon isolate services')
  healthChecks() {
    print("healthChecks");
  }

// TODO(adam): healthChecks, remoteHealthChecks, localStatus can merge to the -l flag
  @SubCommand(help: '')
  remoteHealthChecks() {
    print("remoteHealthChecks");
  }

  // TODO(adam): combine these two commands with optional flag -l for localhost
  @SubCommand(help: '')
  localStatus() {
    print("localStatus");
  }

  // TODO(adam): combine these two commands with optional flag -l for localhost
  @SubCommand(help: '')
  remoteStatus() {
    print("remoteStatus");
  }
}
