dart-carte-du-jour
==================

Pub documentation generation system
-- 

Currently `bin/package_daemon.dart` has two modes to execute in (only
client is implemented). Client mode execution takes parameters to
generate documentation and upload it to cloud storage. In Daemon mode
the dart program will poll the
[http://pub.dartlang.org/packages.json](http://pub.dartlang.org/packages.json)
url for new packages. 

Example of running a client (only works on unix shell envionments as of
now)

```shell
dart bin/package_daemon.dart --verbose --client --sdk
/Applications/dart/dart-sdk --package unittest --version 0.10.1+1
```

Mac OSX has an issue where `gsutil` does not run in threaded mode cause of
`ulimit` settings. One way around that is for the shell process running
the script run the following commands `ulimit -S 1024 && ulimit -S -n
1024`. The uploading portion to cloud storage should not take more then
1-3 minutes. If the upload takes 5 or more then `gsutil` is not running in
multi threaded mode. 

Example of [http://pub.dartlang.org/packages.json](http://pub.dartlang.org/packages.json) response.

```json
{
  "prev": null,
  "packages": [
    "http://pub.dartlang.org/packages/unittest.json",
    "http://pub.dartlang.org/packages/caller_info.json",
    "http://pub.dartlang.org/packages/clean_data.json",
    "http://pub.dartlang.org/packages/angular_ui.json",
    "http://pub.dartlang.org/packages/ng_infinite_scroll.json",
    "http://pub.dartlang.org/packages/smartcanvas.json",
    "http://pub.dartlang.org/packages/circuit.json",
    "http://pub.dartlang.org/packages/bootjack.json",
    "http://pub.dartlang.org/packages/dquery.json",
    "http://pub.dartlang.org/packages/googleclouddatastore.json",
    "http://pub.dartlang.org/packages/shelf.json",
    "http://pub.dartlang.org/packages/scheduled_test.json",
    "http://pub.dartlang.org/packages/purity.json",
    "http://pub.dartlang.org/packages/intl.json",
    "http://pub.dartlang.org/packages/http.json",
    "http://pub.dartlang.org/packages/browser_controller.json",
    "http://pub.dartlang.org/packages/amazon_s3.json",
    "http://pub.dartlang.org/packages/components.json",
    "http://pub.dartlang.org/packages/randomize.json",
    "http://pub.dartlang.org/packages/markdown.json",
    "http://pub.dartlang.org/packages/pshdl_api.json",
    "http://pub.dartlang.org/packages/controls_and_panels.json",
    "http://pub.dartlang.org/packages/math_expressions.json",
    "http://pub.dartlang.org/packages/semantic_ui.json",
    "http://pub.dartlang.org/packages/semantic_ui_for_pub.json",
    "http://pub.dartlang.org/packages/hi_sync.json",
    "http://pub.dartlang.org/packages/hi_files.json",
    "http://pub.dartlang.org/packages/quiver_log.json",
    "http://pub.dartlang.org/packages/awsdart.json",
    "http://pub.dartlang.org/packages/forcemvc.json",
    "http://pub.dartlang.org/packages/eventable.json",
    "http://pub.dartlang.org/packages/transmittable.json",
    "http://pub.dartlang.org/packages/bson.json",
    "http://pub.dartlang.org/packages/code_transformers.json",
    "http://pub.dartlang.org/packages/smoke.json",
    "http://pub.dartlang.org/packages/lists.json",
    "http://pub.dartlang.org/packages/http_server.json",
    "http://pub.dartlang.org/packages/google_oauth2_client.json",
    "http://pub.dartlang.org/packages/json_web_token.json",
    "http://pub.dartlang.org/packages/asn1lib.json",
    "http://pub.dartlang.org/packages/fp.json",
    "http://pub.dartlang.org/packages/barback.json",
    "http://pub.dartlang.org/packages/voronoi.json",
    "http://pub.dartlang.org/packages/coverage.json",
    "http://pub.dartlang.org/packages/oauth2.json",
    "http://pub.dartlang.org/packages/vane.json",
    "http://pub.dartlang.org/packages/image.json",
    "http://pub.dartlang.org/packages/simple_regexp.json",
    "http://pub.dartlang.org/packages/bloodless.json",
    "http://pub.dartlang.org/packages/jwt.json"
  ],
  "pages": 15,
  "next": "http://pub.dartlang.org/packages.json?page=2"
}
```

Example of [http://pub.dartlang.org/packages/angular_ui.json](http://pub.dartlang.org/packages/angular_ui.json) reponse.

```json
{
  "uploaders": [
    "akserg@gmail.com"
  ],
  "name": "angular_ui",
  "versions": [
    "0.1.0",
    "0.2.0",
    "0.2.0+1",
    "0.2.0+2",
    "0.2.0+3",
    "0.2.0+4",
    "0.2.0+5",
    "0.2.0+6",
    "0.2.0+7",
    "0.2.1",
    "0.2.2"
  ]
}
```

- `scripts/github_private_repo_pull` is the github scripts and keys to
pull from a private repository. This would not be needed once the
repository has been open sourced. 

- `scripts/make_image/build_image.sh` is the script used for creating 
the compute engine instance that has latest dart-sdk

- `scripts/quick_launch/` is a collection of scripts for
  launching, killing, ssh a test-instance, currently the scripts are 
  hardcoded. 

- [scope document](https://docs.google.com/document/d/1DYeca9T-FJTePXLksqNoSrOwp8eFlnbqbLs_qGfC99o/edit)

