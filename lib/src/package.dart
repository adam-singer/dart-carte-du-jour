part of carte_de_jour;

/**
 * Class prepresentation of `<package>.json` file.
 */
class Package {
  List<String> uploaders;
  String name;
  List<String> versions;

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

    versions = new List<String>();
    if (data.containsKey('versions')) {
      versions.addAll(data['versions'].toList());
    }
  }

  Map toJson() {
    Map map = {};
    map['name'] = name;
    map['versions'] = versions;
    map['uploaders'] = uploaders;
    return map;
  }

  String toString() => JSON.encode(toJson());

  /**
   * Builds the cache for a package.
   */
  int buildDocumentationCacheSync({Map additionalEnvironment:
      null, String versionConstraint: null, bool allVersions: true}) {
    Map environment = {};
    environment['PUB_CACHE'] = BUILD_DOCUMENTATION_CACHE;
    if (additionalEnvironment != null) {
      environment.addAll(additionalEnvironment);
    }

    List<String> args = ['cache', 'add', name];
    if (versionConstraint != null) {
      args.addAll(['--version', versionConstraint]);
    }

    if (allVersions) {
      args.add('--all');
    }

    Logger.root.finest("pub ${args}");

    ProcessResult processResult = Process.runSync('pub', args,
        environment: environment, runInShell: true);
    stdout.write(processResult.stdout);
    stderr.write(processResult.stderr);
    return processResult.exitCode;
  }

  /**
   * Bootstrap a version of a package.
   */
  int initPackageVersion(String version) {
    String path = join(BUILD_DOCUMENTATION_ROOT_PATH,
        "${name}-${version}");
    return pubInstall(path);
  }

  /**
   * Copy generated documentation package and version to cloud storage.
   */
  int copyDocumentation(String version) {
    String packageFolderPath = "${name}-${version}";
    String workingDirectory = join(BUILD_DOCUMENTATION_ROOT_PATH, packageFolderPath,
        DARTDOC_VIEWER_OUT, 'web');
    String cloudDocumentationPath = _buildCloudStorageDocumentationPath(this, version);
    List<String> args = ['-m', 'cp', '-e', '-c', '-a', 'public-read', '-r', '.',
                         cloudDocumentationPath];

    Logger.root.finest("workingDirectory: ${workingDirectory}");
    Logger.root.finest("gsutil ${args}");
    Stopwatch watch = new Stopwatch();
    watch.start();
    ProcessResult processResult = Process.runSync('gsutil', args, workingDirectory:
        workingDirectory, runInShell: true);
    watch.stop();
    stdout.write(processResult.stdout);
    stderr.write(processResult.stderr);
    Logger.root.finest("Minutes: ${watch.elapsed.inMinutes}");
    return processResult.exitCode;
  }

  /**
   * Moves the packages folder into the root of the web folder. WARNING: this may
   * change in the future versions dartdoc-viewer.
   *
   */
  void moveDocumentationPackages(String version) {
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
  int buildDocumentationSync(String version, String dartSdkPath, {bool verbose: false}) {
    String outputFolder = 'docs';
    String packagesFolder = './packages'; // The pub installed packages
    String workingDirectory = join(BUILD_DOCUMENTATION_ROOT_PATH,
        "${name}-${version}");
    List<String> dartFiles = findDartLibraryFiles(join(workingDirectory, "lib"));
    dartFiles =
        dartFiles.map((e) => basename(e)).map((e) => join("lib", e)).toList();
    List<String> args = ['--compile', '--no-include-sdk', '--include-private',
                         '--out', outputFolder, '--sdk', dartSdkPath,
                         '--package-root', packagesFolder];

    if (verbose) {
      args.add('--verbose');
    }

    args.addAll(dartFiles);

    Logger.root.finest("workingDirectory = ${workingDirectory}");
    Logger.root.finest("docgen ${args}");

    ProcessResult processResult = Process.runSync('docgen', args,
        workingDirectory: workingDirectory, runInShell: true);
    stdout.write(processResult.stdout);
    stderr.write(processResult.stderr);
    Logger.root.fine("docgen exit code = ${processResult.exitCode}");
    return processResult.exitCode;
  }

  bool documentationInstanceAlive(String version) {
    String service_version = "v1";
    String project = "dart-carte-du-jour";
    String instanceName = buildGceName(name, version);
    String zone = "us-central1-a";

    // TODO: Use the dart client apis
    // https://developers.google.com/compute/docs/instances#checkmachinestatus
    List<String> args = ['--service_version=$service_version',
                         '--project=$project',
                         'getinstance',
                         instanceName,
                         '--zone=$zone'];

    Logger.root.finest("gcutil ${args}");

    ProcessResult processResult = Process.runSync('gcutil', args, runInShell: true);
    stdout.write(processResult.stdout);
    stderr.write(processResult.stderr);

    if (processResult.exitCode == 0) {
      return true;
    } else {
      return false;
    }
  }


  // Call gcutil to deploy a node
  int deployDocumentationBuilder(String version) {
    String service_version = "v1";
    String project = "dart-carte-du-jour";
    String instanceName = buildGceName(name, version);
    String zone = "us-central1-a";
    String machineType = "g1-small";
    String network = "default"; // TODO(adam): we should use the internal network
    String externalIpAddress = "ephemeral";
    String serviceAccountScopes = "https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.full_control";
    String image = "https://www.googleapis.com/compute/v1/projects/dart-carte-du-jour/global/images/dart-engine-v1"; // TODO(adam): parameterize this
    String persistentBootDisk = "true";
    String autoDeleteBootDisk = "true";
    String startupScript = buildStartupScript("packages/dart_carte_du_jour/startup_script.mustache"); // "startup-script.sh"; // TODO(adam): dont actually write a startup-script.sh to file system, pass it as a string if possible
    String metadataStartupScript = "startup-script:$startupScript";

    String workingDirectory = "/tmp/"; // TODO(adam): this might need to be the location where the startup-script.sh was generated..
    String metadataPackageName = "package:${name}";
    String metadataPackageVersion = "version:${version}";
    String metadataDartsdkPath = "dartsdk:/dart-sdk";
    String metadataMode = "mode:client";
    String metadataAutoShutdown = "autoshutdown:1";

    List<String> args = ['--service_version=$service_version',
                         '--project=$project',
                         'addinstance',
                         instanceName,
                         '--zone=$zone',
                         '--machine_type=$machineType',
                         '--network=$network',
                         '--external_ip_address=$externalIpAddress',
                         '--service_account_scopes=$serviceAccountScopes',
                         '--image=$image',
                         '--persistent_boot_disk=$persistentBootDisk',
                         '--auto_delete_boot_disk=$autoDeleteBootDisk',
                         '--metadata=$metadataPackageName',
                         '--metadata=$metadataPackageVersion',
                         '--metadata=$metadataDartsdkPath',
                         '--metadata=$metadataMode',
                         '--metadata=$metadataAutoShutdown',
                         '--metadata=$metadataStartupScript'];

    Logger.root.finest("gcutil ${args}");

    ProcessResult processResult = Process.runSync('gcutil', args,
        workingDirectory: workingDirectory, runInShell: true);
    stdout.write(processResult.stdout);
    stderr.write(processResult.stderr);

    return processResult.exitCode;
  }


  Future<PackageBuildInfo> checkPackageIsBuilt(String version) {
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

  void createVersionFile(String version) {
    // TODO(adam): factor this out into a private method.
    String out = join(BUILD_DOCUMENTATION_ROOT_PATH, "${name}-${version}",
          DARTDOC_VIEWER_OUT);
    String versionPath = join(out, 'web', 'VERSION');

    File versionFile = new File(versionPath);
    versionFile.writeAsStringSync(version, flush: true);
  }

  void createPackageBuildInfo(String version, bool successfullyBuilt) {
    // TODO(adam): factor this out into a private method.
    String out = join(BUILD_DOCUMENTATION_ROOT_PATH, "${name}-${version}");
    String packageBuildInfoPath = join(out, PACKAGE_BUILD_INFO_FILE_NAME);
    String now = new DateTime.now().toIso8601String();

    PackageBuildInfo packageBuildInfo = new PackageBuildInfo(name,
        version, now, successfullyBuilt);

    File packageBuildInfoFile = new File(packageBuildInfoPath);
    packageBuildInfoFile.writeAsStringSync(packageBuildInfo.toString());
  }

  int copyVersionFile(String version) {
    String packageFolderPath = "${name}-${version}";
    String workingDirectory = join(BUILD_DOCUMENTATION_ROOT_PATH, packageFolderPath,
        DARTDOC_VIEWER_OUT, 'web');

    String cloudDocumentationPath = _buildCloudStorageDocumentationPath(this, version);
    cloudDocumentationPath = join(cloudDocumentationPath, 'docs');

    List<String> args = ['-m', 'cp', '-e', '-c', '-a', 'public-read', 'VERSION',
                         cloudDocumentationPath];

    Logger.root.finest("workingDirectory: ${workingDirectory}");
    Logger.root.finest("gsutil ${args}");

    // TODO(adam): factor out the runsync of all gsutils
    ProcessResult processResult = Process.runSync('gsutil', args, workingDirectory:
        workingDirectory, runInShell: true);

    stdout.write(processResult.stdout);
    stderr.write(processResult.stderr);

    return processResult.exitCode;
  }

  int copyPackageBuildInfo(String version) {
    String packageFolderPath = "${name}-${version}";
    String workingDirectory = join(BUILD_DOCUMENTATION_ROOT_PATH, packageFolderPath);

    String cloudDocumentationPath = _buildCloudStorageDocumentationPath(this, version);

    List<String> args = ['-m', 'cp', '-e', '-c', '-a', 'public-read',
                         PACKAGE_BUILD_INFO_FILE_NAME,
                         join(cloudDocumentationPath,
                             PACKAGE_BUILD_INFO_FILE_NAME)];

    Logger.root.finest("workingDirectory: ${workingDirectory}");
    Logger.root.finest("gsutil ${args}");

    ProcessResult processResult = Process.runSync('gsutil', args, workingDirectory:
        workingDirectory, runInShell: true);

    stdout.write(processResult.stdout);
    stderr.write(processResult.stderr);

    return processResult.exitCode;
  }
}
