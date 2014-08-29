part of carte_de_jour;

final String PACKAGES_DATA_URI = "http://pub.dartlang.org/packages.json";
final String PACKAGE_STORAGE_ROOT = "gs://www.dartdocs.org/documentation";
final String PACKAGE_HTTP_ROOT = "http://www.dartdocs.org/documentation";
final String DOCUMENTATION_HTTP_ROOT = "http://storage.googleapis.com/www.dartdocs.org/documentation";
final String DARTDOC_VIEWER_OUT = 'dartdoc-viewer/client/out';
final String PACKAGE_BUILD_INFO_FILE_NAME = "package_build_info.json";

// TODO(adam): create a class object that has these as members.
final String BUILD_DOCUMENTATION_CACHE = "/tmp/build_documentation_cache";
final String BUILD_DOCUMENTATION_ROOT_PATH =
"/tmp/build_documentation_cache/hosted/pub.dartlang.org";

final String BUILD_LOGS_ROOT = "gs://www.dartdocs.org/buildlogs/";
final String CLIENT_BUILDER_CONFIG_FILES_ROOT = "gs://dart-carte-du-jour/client_builder_configurations/";

final Uuid uuid_generator = new Uuid();

final String CACHE_CONTROL = "Cache-Control:public,max-age=3600";
final String NO_CACHE_CONTROL = "Cache-Control:public,no-cache,no-store,must-revalidate,max-age=0";
final String COMPRESS_FILE_TYPES = "json,css,html,xml,js,dart,map,txt";
