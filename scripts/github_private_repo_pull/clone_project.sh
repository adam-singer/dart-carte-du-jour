#!/bin/bash
set -x
#GIT_SSH=git_ssh_wrapper git clone github-deploy-dart-carte-du-jour-pull:financeCoding/dart-carte-du-jour.git
chmod go-rwx dart-carte-du-jour-pull
chmod +x git_ssh_wrapper
GIT_SSH=./git_ssh_wrapper git clone git@github.com:financeCoding/dart-carte-du-jour.git
