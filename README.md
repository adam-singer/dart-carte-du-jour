dart-carte-du-jour 
==================

[![Build Status](https://drone.io/github.com/financeCoding/dart-carte-du-jour/status.png)](https://drone.io/github.com/financeCoding/dart-carte-du-jour/latest)

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

- `scripts/daemon_launch/` is a collection of scripts for
  launching, killing, ssh a daemon-isolate, currently the scripts are 
  hardcoded. 

- [scope document](https://docs.google.com/document/d/1DYeca9T-FJTePXLksqNoSrOwp8eFlnbqbLs_qGfC99o/edit)

Configuration settings
--

TODO

Starting and stopping documentation service
--

TODO

Monitoring service
--

TODO