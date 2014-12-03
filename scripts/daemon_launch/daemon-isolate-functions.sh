
DAEMON_ISOLATE_STARTUP_SCRIPT=startup-script.sh
# SSH_PORT=443
SSH_PORT=22
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
  gcutil --service_version="v1" --project=${GCE_PROJECT} addinstance "daemon-isolate" --zone="us-central1-a" --machine_type="g1-small" --network="default" --external_ip_address="ephemeral" --service_account_scopes="https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.full_control" --image="https://www.googleapis.com/compute/v1/projects/dart-carte-du-jour/global/images/dart-daemon-isolate-v1" --persistent_boot_disk="true" --auto_delete_boot_disk="true" --metadata_from_file=startup-script:$DAEMON_ISOLATE_STARTUP_SCRIPT
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

function carte_build_all_latest_index_html() {
  gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://localhost:8884/buildAll
}

function carte_build_latest_index_html() {
  gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://localhost:8884/build/${1}
}

function carte_build_package_version() {
  gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://localhost:8888/build/${1}/${2}
}

function carte_build_latest_index_html_health() {
  gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://localhost:8884/health
}

function _health_report() {
  EXIT_CODE=0;
  if [[ ${1} -eq 200 ]]; then
    echo "daemon_isolate.dart - everything is ok"
  else 
    echo "daemon_isolate.dart - not ok"
    EXIT_CODE=1
  fi


  if [[ ${2} -eq 200 ]];
    then
    echo "daemon_isolate_gce_launcher.dart - everything is ok"
  else 
    echo "daemon_isolate_gce_launcher.dart - not ok"
    EXIT_CODE=1    
  fi  


  if [[ ${3} -eq 200 ]];
    then
    echo "daemon_isolate_build_index.dart - everything is ok"
  else 
    echo "daemon_isolate_build_index.dart - not ok"
    EXIT_CODE=1    
  fi  


  if [[ ${4} -eq 200 ]];
    then
    echo "daemon_isolate_build_package_validation.dart -everything is ok"
  else 
    echo "daemon_isolate_build_package_validation.dart - not ok"
    EXIT_CODE=1    
  fi  


  if [[ ${5} -eq 200 ]];
    then
    echo "daemon_isolate_queue.dart - everything is ok"
  else 
    echo "daemon_isolate_queue.dart - not ok"
    EXIT_CODE=1    
  fi  

  if [[ ${6} -eq 200 ]];
    then
    echo "daemon_isolate_build_latest_index.dart - everything is ok"
  else 
    echo "daemon_isolate_build_latest_index.dart - not ok"
    EXIT_CODE=1    
  fi  

  return ${EXIT_CODE}
}

function carte_health_checks() {
  S1=$(curl -i -s -L -o /dev/null --silent --write-out '%{http_code}' http://127.0.0.1:8889/health)
  S2=$(curl -i -s -L -o /dev/null --silent --write-out '%{http_code}' http://127.0.0.1:8888/health)
  S3=$(curl -i -s -L -o /dev/null --silent --write-out '%{http_code}' http://127.0.0.1:8887/health)
  S4=$(curl -i -s -L -o /dev/null --silent --write-out '%{http_code}' http://127.0.0.1:8886/health)
  S5=$(curl -i -s -L -o /dev/null --silent --write-out '%{http_code}' http://127.0.0.1:8885/health)
  S6=$(curl -i -s -L -o /dev/null --silent --write-out '%{http_code}' http://127.0.0.1:8884/health)
  
  _health_report ${S1} ${S2} ${S3} ${S4} ${S5} ${S6}
}

function carte_remote_health_checks() {
  S1=$(gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl -i -s -L -o /dev/null --silent --write-out '%{http_code}' http://127.0.0.1:8889/health)
  S2=$(gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl -i -s -L -o /dev/null --silent --write-out '%{http_code}' http://127.0.0.1:8888/health)
  S3=$(gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl -i -s -L -o /dev/null --silent --write-out '%{http_code}' http://127.0.0.1:8887/health)
  S4=$(gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl -i -s -L -o /dev/null --silent --write-out '%{http_code}' http://127.0.0.1:8886/health)
  S5=$(gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl -i -s -L -o /dev/null --silent --write-out '%{http_code}' http://127.0.0.1:8885/health)
  S6=$(gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl -i -s -L -o /dev/null --silent --write-out '%{http_code}' http://127.0.0.1:8884/health)
  _health_report ${S1} ${S2} ${S3} ${S4} ${S5} ${S6}
}

function carte_local_status() {
  S1=$(curl http://127.0.0.1:8889/health)
  S2=$(curl http://127.0.0.1:8888/health)
  S3=$(curl http://127.0.0.1:8887/health)
  S4=$(curl http://127.0.0.1:8886/health)
  S5=$(curl http://127.0.0.1:8885/health)
  S6=$(curl http://127.0.0.1:8884/health) 

  echo "${S1}"
  echo "${S2}"
  echo "${S3}"
  echo "${S4}"
  echo "${S5}" 
  echo "${S6}"
}

function carte_remote_status() {
  S1=$(gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://127.0.0.1:8889/health)
  S2=$(gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://127.0.0.1:8888/health)
  S3=$(gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://127.0.0.1:8887/health)
  S4=$(gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://127.0.0.1:8886/health)
  S5=$(gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://127.0.0.1:8885/health)
  S6=$(gcutil --service_version="v1" --project=${GCE_PROJECT} ssh --ssh_user=${SSH_USER} --ssh_port=${SSH_PORT} daemon-isolate curl http://127.0.0.1:8884/health)

  echo "${S1}"
  echo "${S2}"
  echo "${S3}"
  echo "${S4}"
  echo "${S5}" 
  echo "${S6}"
}

function carte_update_404_page() {
   if [ -z "$1" ]; then
    echo "No argument supplied"
   else 
    S1=$(gsutil cp -e -c -z json,css,html,xml,js,dart,map,txt -a public-read ${1} gs://www.dartdocs.org/404.html)
    echo "${1}"
   fi
}
