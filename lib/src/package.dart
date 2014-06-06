part of carte_de_jour;

/**
 * Execute `pub install` at the `workingDirectory`
 */
int pubInstall(String workingDirectory) {
  List<String> args = ['install'];
  ProcessResult processResult = Process.runSync('pub', args, workingDirectory:
      workingDirectory, runInShell: true);
  Logger.root.finest(processResult.stdout);
  Logger.root.severe(processResult.stderr);
  return processResult.exitCode;
}

String _buildCloudStorageDocumentationPath(Package package, Version version) {
  return join(PACKAGE_STORAGE_ROOT, package.name, version.toString());
}

String _buildHttpDocumentationPath(Package package, Version version) {
  return join(DOCUMENTATION_HTTP_ROOT, package.name, version.toString(), PACKAGE_BUILD_INFO_FILE_NAME);
}

class VersionBuild {
  final String name;
  final Version version;
  final bool build;
  final PackageBuildInfo packageBuildInfo;
  VersionBuild._(this.name, this.version, this.build, this.packageBuildInfo);
  factory VersionBuild(String name, Version version, bool build,
      {PackageBuildInfo packageBuildInfo: null}) {
    return new VersionBuild._(name, version, build, packageBuildInfo);
  }
}

/**
 * Class prepresentation of `<package>.json` file.
 */
class Package {
  List<String> uploaders;
  String name;
  List<Version> versions;

  Package(this.name, this.versions, {this.uploaders});

  Package.fromJson(Map data) {
    uploaders = new List<String>();
    if (data.containsKey('uploaders')) {
      for (var u in data['uploaders']) {
        uploaders.add(u);
      }
    }

    if (data.containsKey('name')) {
      name = data['name'];
    }

    versions = new List<Version>();
    if (data.containsKey('versions')) {
      versions.addAll(data['versions'].map((v)=>new Version.parse(v)).toList());
    }
  }

  Map toJson() {
    Map map = {};
    map['name'] = name;
    map['versions'] = versions.map((e)=>e.toString()).toList();
    map['uploaders'] = uploaders;
    return map;
  }

  String toString() => JSON.encode(toJson());

  /**
   * Builds the cache for a package.
   */
  // TODO: use VersionConstraint object
  int buildDocumentationCacheSync({Map additionalEnvironment:
      null, Version versionConstraint: null, bool allVersions: true}) {
    Map environment = {};
    environment['PUB_CACHE'] = BUILD_DOCUMENTATION_CACHE;
    if (additionalEnvironment != null) {
      environment.addAll(additionalEnvironment);
    }

    List<String> args = ['cache', 'add', name];
    if (versionConstraint != null) {
      args.addAll(['--version', versionConstraint.toString()]);
    }

    if (allVersions) {
      args.add('--all');
    }

    Logger.root.finest("pub ${args}");

    ProcessResult processResult = Process.runSync('pub', args,
        environment: environment, runInShell: true);
    Logger.root.finest(processResult.stdout);
    Logger.root.severe(processResult.stderr);
    return processResult.exitCode;
  }

  /**
   * Bootstrap a version of a package.
   */
  int initPackageVersion(Version version) {
    String path = join(BUILD_DOCUMENTATION_ROOT_PATH,
        "${name}-${version}");
    return pubInstall(path);
  }

  /**
   * Copy generated documentation package and version to cloud storage.
   */
  int copyDocumentation(Version version) {
    String packageFolderPath = "${name}-${version}";
    String workingDirectory = join(BUILD_DOCUMENTATION_ROOT_PATH, packageFolderPath,
        DARTDOC_VIEWER_OUT, 'web');
    String cloudDocumentationPath = _buildCloudStorageDocumentationPath(this, version);
    List<String> args = ['-h', CACHE_CONTROL,
                         '-m', 'cp',
                         '-e',
                         '-c',
                         '-z', COMPRESS_FILE_TYPES,
                         '-a', 'public-read',
                         '-r', '.',
                         cloudDocumentationPath];

    Logger.root.finest("workingDirectory: ${workingDirectory}");
    Logger.root.finest("gsutil ${args}");
    Stopwatch watch = new Stopwatch();
    watch.start();
    ProcessResult processResult = Process.runSync('gsutil', args, workingDirectory:
        workingDirectory, runInShell: true);
    watch.stop();
    Logger.root.finest(processResult.stdout);
    Logger.root.severe(processResult.stderr);
    Logger.root.finest("Minutes: ${watch.elapsed.inMinutes}");
    return processResult.exitCode;
  }

  /**
   * Moves the packages folder into the root of the web folder. WARNING: this may
   * change in the future versions dartdoc-viewer.
   *
   */
  void moveDocumentationPackages(Version version) {
    String out = join(BUILD_DOCUMENTATION_ROOT_PATH, "${name}-${version}",
        DARTDOC_VIEWER_OUT);
    String webPath = join(out, 'web');
    String webPackagesPath = join(webPath, 'packages');
    String outPackagesPath = join(out, 'packages');

    // 1) remove symlink in out/web/packages
    Directory webPackagesDirectory = new Directory(webPackagesPath);
    webPackagesDirectory.deleteSync();

    // 2) only copy dartdoc_viewer specific packages
    _moveDartDocViewerSpecificFiles(outPackagesPath, webPackagesPath);
  }

  void _moveDartDocViewerSpecificFiles(String outPackagesPath, String webPackagesPath) {
    // mkdir web/packages
    // copy -r packages/web_components web/packages/
    // copy -r packages/polymer web/packages/

    Directory webPackagesDirectory = new Directory(webPackagesPath);
    webPackagesDirectory.createSync();

    String outWebComponentsPath = join(outPackagesPath, "web_components");
    String outPolymerPath = join(outPackagesPath, "polymer");
    String outDartdocViewerPath = join(outPackagesPath, "dartdoc_viewer");

    String webWebComponentsPath = join(webPackagesPath, "web_components");
    String webPolymerPath = join(webPackagesPath, "polymer");
    String webDartdocViewerPath = join(webPackagesPath, "dartdoc_viewer");

    Directory outWebComponentsDirectory = new Directory(outWebComponentsPath);
    Directory outPolymerDirectory = new Directory(outPolymerPath);
    Directory outDartdocViewerDirectory = new Directory(outDartdocViewerPath);

    outWebComponentsDirectory.renameSync(webWebComponentsPath);
    outPolymerDirectory.renameSync(webPolymerPath);
    outDartdocViewerDirectory.renameSync(webDartdocViewerPath);
  }

  /**
   * Builds documentation for a particular version of a package.
   */
  int buildDocumentationSync(Version version, String dartSdkPath, {bool verbose: false}) {
    String outputFolder = 'docs';
    String packagesFolder = './packages'; // The pub installed packages
    String workingDirectory = join(BUILD_DOCUMENTATION_ROOT_PATH,
        "${name}-${version}");

    List<String> args = ['--compile',
                         '--no-include-sdk',
                         '--no-include-dependent-packages',
                         '--out', outputFolder,
                         '--sdk', dartSdkPath,
                         '--package-root', packagesFolder];

    if (verbose) {
      args.add('--verbose');
    }

    args.add('.');

    Logger.root.finest("workingDirectory = ${workingDirectory}");
    Logger.root.finest("docgen ${args}");

    ProcessResult processResult = Process.runSync('docgen', args,
        workingDirectory: workingDirectory, runInShell: true);
    Logger.root.finest(processResult.stdout);
    Logger.root.severe(processResult.stderr);
    Logger.root.fine("docgen exit code = ${processResult.exitCode}");
    return processResult.exitCode;
  }

  Future<PackageBuildInfo> checkPackageIsBuilt(Version version) {
    String docPath = _buildHttpDocumentationPath(this, version);

    // TODO: response / error handling.
    return http.get(docPath).then((response) {
      // If we do not find a package build info file then return the package
      // is not built.
      if (response.statusCode != 200) {
        return null;
      }

      var data = JSON.decode(response.body);
      PackageBuildInfo packageBuildInfo = new PackageBuildInfo.fromJson(data);
      return packageBuildInfo;
    });
  }

  Stream<VersionBuild> checkVersionBuilds(PackageBuildInfoDataStore packageBuildInfoDataStore) {
    StreamController<VersionBuild> controller;
    var _versions = this.versions.toList();
    var running = false;

    void callback() {
      if (running == false) {
        return;
      }

      if (_versions.isEmpty) {
        controller.close();
        return;
      }

      var _version = _versions.removeLast();

      packageBuildInfoDataStore.fetch(this.name, _version)
      .then((PackageBuildInfo packageBuildInfo) {
        VersionBuild versionBuild;

        if (packageBuildInfo != null) {
          // Do not rebuild package since it already exists.
          // TODO: make better with an option to force rebuilds.
          versionBuild = new VersionBuild(this.name, _version, false, packageBuildInfo: packageBuildInfo);
        } else {
          // Build package for the first time
          versionBuild = new VersionBuild(this.name, _version, true);
        }

        controller.add(versionBuild);
      }).then((_) => callback())
      .catchError((error){
        Logger.root.severe("failed checkVersionBuilds ${name} ${_version.toString()}");
      });
    }

    void startStream() {
      running = true;
      callback();
    }

    void stopStream() {
      running = false;
    }

    controller = new StreamController<VersionBuild>(
        onListen: startStream,
        onPause: stopStream,
        onResume: startStream,
        onCancel: stopStream);

    return controller.stream;
  }

  @deprecated
  Stream<Map> checkAllPackageVersionsIsBuilt() {
    StreamController<Map> controller;
    var _versions = this.versions.toList();
    var running = false;

    void callback() {
      if (running == false) {
        return;
      }


      if (_versions.isEmpty) {
        controller.close();
        return;
      }

      var _version = _versions.removeLast();


      String docPath = _buildHttpDocumentationPath(this, _version);
      http.get(docPath).then((response) {
        if (response.statusCode != 200) {
          // Build package since no package build info was found
          // TODO: make class out of this.
          controller.add({'name': this.name, 'build': true, 'version': _version});
        } else {
          // Do not build a package if we found it.
          var data = JSON.decode(response.body);
          PackageBuildInfo packageBuildInfo = new PackageBuildInfo.fromJson(data);
          controller.add({'name': packageBuildInfo.name,
            'build': false,
            'version': packageBuildInfo.version});
        }
      }).then((_) => callback())
      .catchError((error) {
        Logger.root.severe("failed checkAllPackageVersionsIsBuilt http.get $docPath");
      });
    }

    void startStream() {
      running = true;
      callback();
    }

    void stopStream() {
      running = false;
    }

    controller = new StreamController<Map>(
        onListen: startStream,
        onPause: stopStream,
        onResume: startStream,
        onCancel: stopStream);

    return controller.stream;
  }

  void createVersionFile(Version version) {
    // TODO(adam): factor this out into a private method.
    String out = join(BUILD_DOCUMENTATION_ROOT_PATH, "${name}-${version}",
          DARTDOC_VIEWER_OUT);
    String versionPath = join(out, 'web', 'VERSION');

    File versionFile = new File(versionPath);
    versionFile.writeAsStringSync(version.toString(), flush: true);
  }

  void createPackageBuildInfo(Version version, bool successfullyBuilt) {
    // TODO(adam): factor this out into a private method.
    String out = join(BUILD_DOCUMENTATION_ROOT_PATH, "${name}-${version}");
    String packageBuildInfoPath = join(out, PACKAGE_BUILD_INFO_FILE_NAME);
    String now = new DateTime.now().toIso8601String();

    PackageBuildInfo packageBuildInfo = new PackageBuildInfo(name,
        version, now, successfullyBuilt);

    File packageBuildInfoFile = new File(packageBuildInfoPath);
    packageBuildInfoFile.writeAsStringSync(packageBuildInfo.toString());
  }

  int copyVersionFile(Version version) {
    String packageFolderPath = "${name}-${version}";
    String workingDirectory = join(BUILD_DOCUMENTATION_ROOT_PATH, packageFolderPath,
        DARTDOC_VIEWER_OUT, 'web');

    String cloudDocumentationPath = _buildCloudStorageDocumentationPath(this, version);
    cloudDocumentationPath = join(cloudDocumentationPath, 'docs');

    List<String> args = ['-h', CACHE_CONTROL,
                         '-m', 'cp',
                         '-e',
                         '-c',
                         '-z', COMPRESS_FILE_TYPES,
                         '-a', 'public-read',
                         'VERSION', cloudDocumentationPath];

    Logger.root.finest("workingDirectory: ${workingDirectory}");
    Logger.root.finest("gsutil ${args}");

    // TODO(adam): factor out the runsync of all gsutils
    ProcessResult processResult = Process.runSync('gsutil', args, workingDirectory:
        workingDirectory, runInShell: true);

    Logger.root.finest(processResult.stdout);
    Logger.root.severe(processResult.stderr);

    return processResult.exitCode;
  }

  int copyPackageBuildInfo(Version version) {
    String packageFolderPath = "${name}-${version}";
    String workingDirectory = join(BUILD_DOCUMENTATION_ROOT_PATH, packageFolderPath);

    String cloudDocumentationPath = _buildCloudStorageDocumentationPath(this, version);

    List<String> args = ['-h', CACHE_CONTROL,
                         '-m', 'cp',
                         '-e',
                         '-c',
                         '-a', 'public-read',
                         PACKAGE_BUILD_INFO_FILE_NAME,
                         join(cloudDocumentationPath,
                             PACKAGE_BUILD_INFO_FILE_NAME)];

    Logger.root.finest("workingDirectory: ${workingDirectory}");
    Logger.root.finest("gsutil ${args}");

    ProcessResult processResult = Process.runSync('gsutil', args, workingDirectory:
        workingDirectory, runInShell: true);

    Logger.root.finest(processResult.stdout);
    Logger.root.severe(processResult.stderr);

    return processResult.exitCode;
  }
}
