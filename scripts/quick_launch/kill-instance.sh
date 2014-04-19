#!/bin/bash
set -x 
gcutil --project="dart-carte-du-jour" deleteinstance --force --delete_boot_pd --zone=us-central1-a daemon-isolate
