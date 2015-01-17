# Changelog - dart-carte-du-jour

### 0.0.10 2015-01-16 (SDK 1.9.0-dev.3.0 r42684)

- Created `DatastoreConnection` to explicitly open and close datastore connections on each usage.
- Eased timing on fetching all packages from pub.dartlang.org to one second.

### 0.0.9 2014-12-02 (SDK 1.8.0-dev.4.6 r41978)

- Removed builder instances from behind proxy
- Removed port 443 for SSH

### 0.0.8 2014-05-19 (SDK 1.4.0-dev.6.7 r36210)

- Displaying one line per package on [www.dartdocs.org](http://www.dartdocs.org)
- Removed old build index code
- Added support for `index.json` file uploaded to [index.json](http://www.dartdocs.org/index.json)
- Pin version of datastore client api
- Add metaview port for mobile
- Created new daemon-isolate image `dart-daemon-isolate-v1`
- Add proxy configuration to node instances

### 0.0.7 2014-05-12 (SDK 1.4.0-dev.6.3 r35960)

- More documentation
- Addtional shell script functions available
- Health checks for isolates available
- Fixed bug with inbox queue

### 0.0.6 2014-05-10 (SDK 1.4.0-dev.6.2 r35890)

- Added explicit setting for file cache on cloud storage
- Content type changed so log files are not downloaded by default
- Gzip log files
- Decreased callback to 10 seconds
- Added script ro rebuild all packages
- Added datastore indexes
- Reduced max instances to 20
- Added more error handling
- Added verbose option to `daemon_isolate`

### 0.0.5 2014-05-06 (SDK 1.4.0-dev.5.1 r35677)

- Increased max gce nodes to 75
- Added local rest interface for building and rebuilding packages
- Checking datastore as the single point of record
- Updated shell scripts

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