library test_runner;

import 'src/client_builder_config_test.dart' as client_builder_config_test;
import 'src/google_compute_engine_config_test.dart' as google_compute_engine_config_test;
import 'src/model_test.dart' as model_test;
import 'src/script_generation_test.dart' as script_generation_test;
import 'src/version_test.dart' as version_test;

void main() {
  client_builder_config_test.main();
  google_compute_engine_config_test.main();
  model_test.main();
  script_generation_test.main();
  version_test.main();
}
