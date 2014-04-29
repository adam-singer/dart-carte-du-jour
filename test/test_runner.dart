library test_runner;

import 'src/test_gce.dart' as test_gce;
import 'src/test_library_finder.dart' as test_library_finder;
import 'src/test_model.dart' as test_model;
import 'src/test_script_generation.dart' as test_script_generation;
import 'src/test_version.dart' as test_version;

void main() {
  test_gce.main();
  test_library_finder.main();
  test_model.main();
  test_script_generation.main();
  test_version.main();
}
