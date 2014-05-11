
DAEMON_ISOLATE_STARTUP_SCRIPT=startup-script.sh
SSH_PORT=443
SSH_USER=financeCoding
GCE_PROJECT=dart-carte-du-jour

function carte_catlog() {
  gsutil cat gs://www.dartdocs.org/buildlogs/${1}-startupscript.log
}

function carte_catconfig() {
  gsutil cat gs://dart-carte-du-jour/client_builder_configurations/${1}.json
}

function carte_list() {
  gcutil --service_version="v1" --project=${GCE_PROJECT} listinstances
}

function carte_ssh_daemon_isolate() {
  gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate
}

function carte_restart_daemon_isolate() {
  carte_stop_daemon_isolate
  carte_start_daemon_isolate
}

function carte_start_daemon_isolate() {
	# TODO: request y/n on startup script location
  gcutil --service_version="v1" --project=${GCE_PROJECT} addinstance "daemon-isolate" --zone="us-central1-a" --machine_type="g1-small" --network="default" --external_ip_address="ephemeral" --service_account_scopes="https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.full_control" --image="https://www.googleapis.com/compute/v1/projects/dart-carte-du-jour/global/images/dart-engine-v1" --persistent_boot_disk="true" --auto_delete_boot_disk="true" --metadata_from_file=startup-script:$DAEMON_ISOLATE_STARTUP_SCRIPT
}

function carte_tail_daemon_isolate() {
  gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate tail -f /var/log/startupscript.log
}

function carte_tail_instance() {
  gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} ${1} tail -f /var/log/startupscript.log
}

function carte_stop_daemon_isolate() {
  gcutil --service_version="v1" --project=${GCE_PROJECT} deleteinstance --force --delete_boot_pd --zone=us-central1-a daemon-isolate
}

function carte_build_package() {
  gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://localhost:8889/build/${1}
}

function carte_rebuild_package() {
  gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://localhost:8889/rebuild/${1}
}

function carte_buildall_packages() {
  gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://localhost:8889/buildAll
}

function carte_rebuildall_packages() {
  gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://localhost:8889/rebuildAll
}

function carte_build_first_page() {
  gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://localhost:8889/buildFirstPage
}

function carte_build_index_html() {
  gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://localhost:8887/buildIndexHtml
}

function build_package_version() {
  gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://localhost:8888/build/${1}/${2}
}
