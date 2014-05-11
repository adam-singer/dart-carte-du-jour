dart-carte-du-jour [www.dartdocs.org](http://www.dartdocs.org)
==================

[![Build Status](https://drone.io/github.com/financeCoding/dart-carte-du-jour/status.png)](https://drone.io/github.com/financeCoding/dart-carte-du-jour/latest)

Introduction
--

TODO

Configuration settings
--

TODO

Starting and stopping documentation service
--

Only authorized users are able to start and stop the `daemon-isolate`

Starting the `daemon-isolate`

```shell 
cd dart-carte-du-jour/scripts/daemon_launch
./launch-instance.sh
```

Stopping the `daemon-isolate`

```shell 
cd dart-carte-du-jour/scripts/daemon_launch
./kill-instance.sh
```

Monitoring service
--

TODO

Sending commands to daemon-isolate service
---

*daemon-isolate* service runs multiple isolates. Each isolate can receive 
commands over `http://localhost:<isolate_port>`. One `isolate_port` is open for
each isolate. 



- daemon_isolate.dart 

port | path | function
--- | --- | ---
8889 | `/build/(.*)` | build all versions of a `package`
8889 | `/rebuild/(.*)` | force rebuild of all versions of a `package`
8889 | `/buildAll` | build all packages and versions of those packages
8889 | `/rebuildAll` | force rebuild of all packages and versions of those packages
8889 | `/buildFirstPage` | build first page of packages on [pub.dartlang.org](http://pub.dartlang.org/)

- daemon_isolate_build_index.dart 

port | path | function
--- | --- | ---
 8887 | `/buildIndexHtml` | rebuild [www.dartdocs.org](www.dartdocs.org) index.html, failed/index.html and history.html 

- daemon_isolate_gce_launcher.dart 

port | path | function
--- | --- | ---
8888 | `/build/(.*)\/(.*)` | force build `package` and `version`

- daemon_isolate_build_package_validation.dart no services
- daemon_isolate_queue.dart no services

Helper shell script functions for authorized users can be found in `dart-carte-du-jour/scripts/daemon_launch/daemon-isolate-functions.sh`

TODO: examples of each

Pub documentation generation system
-- 

- `bin/client_builder.dart` takes parameters to
generate documentation and uploads it to cloud storage. `client_builder.dart`
can be run locally from DartEditor for functional testing. 

Example:

```shell
dart bin/client_builder.dart --verbose --sdk
/Applications/dart/dart-sdk --package unittest --version 0.10.1+1
```

Mac OSX has an issue where `gsutil` does not run in threaded mode cause of
`ulimit` settings. One way around that is for the shell process running
the script run the following commands `ulimit -S 1024 && ulimit -S -n
1024`. The uploading portion to cloud storage should not take more then
1-3 minutes. If the upload takes 5 or more then `gsutil` is not running in
multi threaded mode. 

- `bin/daemon_isolate.dart` is the main service that polls pub for packages to
build. 

- `scripts/make_image/build_image.sh` is the script used for creating 
the compute engine instance that has latest dart-sdk

- [scope document](https://docs.google.com/document/d/1DYeca9T-FJTePXLksqNoSrOwp8eFlnbqbLs_qGfC99o/edit)
