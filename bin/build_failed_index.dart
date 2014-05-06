import "dart:io";
import "dart:convert";

import 'package:mustache/mustache.dart' as mustache;

import 'package:dart_carte_du_jour/carte_de_jour.dart';

String buildDartDocsIndexHtml(Map renderData, {String dartDocsTemplate:
                                "bin/dartdocs_failed_index.html.mustache"}) {
  String indexTemplate = new File(dartDocsTemplate).readAsStringSync();
  var template = mustache.parse(indexTemplate);
  var indexHtml = template.renderString(renderData, htmlEscapeValues: false);
  return indexHtml;
}

int copyDartDocsIndexHtml(String dartDocsIndexPath) {
  List<String> args = ['-m', 'cp',
                       '-e',
                       '-c',
                       '-z', COMPRESS_FILE_TYPES,
                       '-a', 'public-read',
                       dartDocsIndexPath, "gs://www.dartdocs.org/failed/index.html"];
  ProcessResult processResult = Process.runSync('gsutil', args, runInShell: true);
  stdout.write(processResult.stdout);
  stderr.write(processResult.stderr);
  return processResult.exitCode;
}

void main() {
  String configFile = new File("bin/config.json").readAsStringSync();
  Map config = JSON.decode(configFile);
  String rsaPrivateKey = new File(config["rsaPrivateKey"]).readAsStringSync();
  GoogleComputeEngineConfig googleComputeEngineConfig =
    new GoogleComputeEngineConfig(config["projectId"], config["projectNumber"],
        config["serviceAccountEmail"], rsaPrivateKey);

  PackageBuildInfoDataStore packageBuildInfoDataStore
      = new PackageBuildInfoDataStore(googleComputeEngineConfig);

  packageBuildInfoDataStore.fetchBuilt(false)
  .then((List<PackageBuildInfo> packageBuildInfos) {
    Map renderData = {'docsUrls': []};

    renderData['docsUrls'].addAll(packageBuildInfos.map((packageBuildInfo) {
      Uri httpBuildLog;

      if (packageBuildInfo.buildLog != null && packageBuildInfo.buildLog.isNotEmpty) {
        Uri gsBuildLog = Uri.parse(packageBuildInfo.buildLog);
        httpBuildLog = new Uri.http(gsBuildLog.host, gsBuildLog.path);
      } else {
        httpBuildLog = new Uri.http("www.dartdocs.org", "/failed/notfound.html");
      }


      return {
        "name": packageBuildInfo.name,
        "version": packageBuildInfo.version,
        "url": httpBuildLog.toString()
      };
    }).toList());

    File dartDocsIndex = new File("dartdocs_failed_index.html");
    dartDocsIndex.writeAsStringSync(buildDartDocsIndexHtml(renderData));
    copyDartDocsIndexHtml("dartdocs_failed_index.html");
    dartDocsIndex.deleteSync();
  });
}
