# Changelog - dart-carte-du-jour

### 0.0.4 2014-05-03 (SDK 1.4.0-dev.4.0 r35362)

- Restructed tests
- Enabled drone.io and buid badge
- Added client builder configuration
- Added support for multi-package builds on a single client
- Added local http server to add packages to build queue
- Switched main isolate to use new client configuration builds

### 0.0.3 2014-04-27 (SDK 1.4.0-dev.4.0 r35362)

- Startup script now pull config and private key files
- Removed all print calls
- Now pushes results to datastore entities
- Datastore entities include uri to build logs on cloud storage
- Added isolate to build index.html
- Last built is indexable

### 0.0.2 2014-04-24 (SDK 1.4.0-dev.2.2 r35068)

- Added `Version` object
- Removed all code of `--mode` commands
- Added storage class for datastore 
- Removed private repo configurations 
- Added one time fetch and build all of latest packages

### 0.0.1 2014-04-20 (SDK 1.4.0-dev.2.2 r35068)

- Initial release