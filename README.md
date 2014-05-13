dart-carte-du-jour [www.dartdocs.org](http://www.dartdocs.org)
==================

[![Build Status](https://drone.io/github.com/financeCoding/dart-carte-du-jour/status.png)](https://drone.io/github.com/financeCoding/dart-carte-du-jour/latest)

Introduction
--

TODO

Configuration settings
--

Configuration settings for project and google related services are stored on 
cloud storage as a plain json file. Upon startup of `daemon-isolate` the
`config.json` file is copied to the compute engine instance. 

```
gsutil cat gs://dart-carte-du-jour/configurations/config.json
{
  "projectId":"dart-carte-du-jour",
  "projectNumber":"00000000001",
  "serviceAccountEmail":"00000000001-xyz@developer.gserviceaccount.com",
  "rsaPrivateKey":"bin/rsa_private_key.pem",
  "sdkPath":"/dart-sdk"
}
```

The other configuration that is copied from cloud storage is `rsa_private_key.pem` file.
`rsa_private_key.pem` is the key file for google api services called from dart. 

```
gsutil ls gs://dart-carte-du-jour/configurations/rsa_private_key.pem
```

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

Monitoring
--

Authorized users can check if the `daemon-isolate` is still alive and all
isolates have not bailed out by running the following script. 

```shell
cd dart-carte-du-jour/scripts/daemon_launch
source daemon-isolate-functions.sh && carte_remote_health_checks
```

output:

```
daemon_isolate.dart - everything is ok
daemon_isolate_gce_launcher.dart - everything is ok
daemon_isolate_build_index.dart - everything is ok
daemon_isolate_build_package_validation.dart -everything is ok
daemon_isolate_queue.dart - everything is ok
```

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
8889 | `/health` | health check 

- daemon_isolate_gce_launcher.dart 

port | path | function
--- | --- | ---
8888 | `/build/(.*)\/(.*)` | force build `package` and `version`
8888 | `/health` | health check 

- daemon_isolate_build_index.dart 

port | path | function
--- | --- | ---
 8887 | `/buildIndexHtml` | rebuild [www.dartdocs.org](www.dartdocs.org) index.html, failed/index.html and history.html 
 8887 | `/health` | health check 


- daemon_isolate_build_package_validation.dart

port | path | function
--- | --- | ---
 8886 | `/health` | health check 


- daemon_isolate_queue.dart 

port | path | function
--- | --- | ---
 8885 | `/health` | health check 


Helper shell script functions for authorized users

```shell
cd dart-carte-du-jour/scripts/daemon_launch
source daemon-isolate-functions.sh
```

In bash shell type `carte_<tab>` to see the list of functions available. 

```
–(~/dart/dart-carte-du-jour/scripts/daemon_launch)–($ carte_
carte_build_first_page        carte_rebuild_package
carte_build_index_html        carte_rebuildall_packages
carte_build_package           carte_remote_health_checks
carte_build_package_version   carte_remote_status
carte_buildall_packages       carte_restart_daemon_isolate
carte_catconfig               carte_ssh_daemon_isolate
carte_catlog                  carte_start_daemon_isolate
carte_health_checks           carte_stop_daemon_isolate
carte_list                    carte_tail_daemon_isolate
carte_local_status            carte_tail_instance
``` 

See the `daemon-isolate-functions.sh` script for paramters of the functions. 
