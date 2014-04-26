import "dart:io";
import "dart:convert";

import 'package:mustache/mustache.dart' as mustache;

import 'package:dart_carte_du_jour/carte_de_jour.dart';

String buildDartDocsIndexHtml(Map renderData, {String dartDocsTemplate:
                                "bin/dartdocs_index.html.mustache"}) {
  String indexTemplate = new File(dartDocsTemplate).readAsStringSync();
  var template = mustache.parse(indexTemplate);
  var indexHtml = template.renderString(renderData, htmlEscapeValues: false);
  return indexHtml;
}

int copyDartDocsIndexHtml(String dartDocsIndexPath) {
  List<String> args = ['-m', 'cp', '-e', '-c', '-a', 'public-read',
                       dartDocsIndexPath, "gs://www.dartdocs.org/index.html"];
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

  packageBuildInfoDataStore.fetchBuilt()
  .then((List<PackageBuildInfo> packageBuildInfos) {
    Map renderData = {'docsUrls': []};

    renderData['docsUrls'].addAll(packageBuildInfos.map((packageBuildInfo) {
      return {
        "name": packageBuildInfo.name,
        "version": packageBuildInfo.version,
        "url": 'http://www.dartdocs.org/documentation/'
          '${packageBuildInfo.name}/${packageBuildInfo.version}/index.html#'
          '${packageBuildInfo.name}'
      };
    }).toList());

    File dartDocsIndex = new File("dartdocs_index.html");
    dartDocsIndex.writeAsStringSync(buildDartDocsIndexHtml(renderData));
    copyDartDocsIndexHtml("dartdocs_index.html");
    dartDocsIndex.deleteSync();
  });
}
