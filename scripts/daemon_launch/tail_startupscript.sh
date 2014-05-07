gcutil --service_version=v1 --project=dart-carte-du-jour ssh --ssh_user=financeCoding --ssh_port=443 ${1} tail -f /var/log/startupscript.log
