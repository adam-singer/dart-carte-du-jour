
function catlog() {
  gsutil cat gs://www.dartdocs.org/buildlogs/${1}-startupscript.log
}

function catconfig() {
  gsutil cat gs://dart-carte-du-jour/client_builder_configurations/${1}.json
}

function list() {
  gcutil --service_version=v1 --project=dart-carte-du-jour listinstances
}

