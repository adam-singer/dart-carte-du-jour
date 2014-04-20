import "dart:io";
import "dart:convert";

import 'package:mustache/mustache.dart' as mustache;

String buildDartDocsIndexHtml(Map renderData, {String dartDocsTemplate:
                                "dartdocs_index.html.mustache"}) {
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

String bqIsBuiltQuery() {
  List<String> args = ['--format=json', '--quiet', 'query', '--max_rows=1000000',
                       'SELECT name, version FROM [test_dummy_data_set.my_table]'
                       ' WHERE isBuilt = true LIMIT 10000'];
  ProcessResult processResult = Process.runSync('bq', args, runInShell: true);
  stdout.write(processResult.stdout);
  stderr.write(processResult.stderr);
  return processResult.stdout;
}

void main() {
  List isBuiltPackages = JSON.decode(bqIsBuiltQuery());
  Map renderData = {'docsUrls': []};

  renderData['docsUrls'].addAll(isBuiltPackages.map((package) => {
      "name": package["name"],
      "version": package["version"],
      "url": 'http://www.dartdocs.org/documentation/'
        '${package["name"]}/${package["version"]}/index.html#${package["name"]}'
    }).toList());

  File dartDocsIndex = new File("dartdocs_index.html");
  dartDocsIndex.writeAsStringSync(buildDartDocsIndexHtml(renderData));
  copyDartDocsIndexHtml("dartdocs_index.html");
  dartDocsIndex.deleteSync();
}
