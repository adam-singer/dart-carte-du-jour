#!/usr/bin/env bash
set -x

gcutil --service_version="v1" --project="dart-carte-du-jour" addinstance bootstrap-instance --zone="us-central1-a" --machine_type="g1-small" --network="default" --external_ip_address="ephemeral" --service_account_scopes="https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.full_control" --image="https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-7-wheezy-v20140318" --persistent_boot_disk="true"

# After logging in to the created node the following commands need to be run.
# gcutil --service_version="v1" --project="dart-carte-du-jour" ssh  --ssh_user=financeCoding --zone="us-central1-a" "bootstrap-instance"

# TODO(adam): move to startup script.

# Add an addtional source for the latest glibc
# sudo sed -i '1i deb http://ftp.us.debian.org/debian/ jessie main' /etc/apt/sources.list

# Update sources
# sudo apt-get update

# Download latest glibc
# sudo DEBIAN_FRONTEND=noninteractive apt-get install -y libc6 libc6-dev libc6-dbg git screen unzip vim

# Download the latest dart sdk
# wget http://storage.googleapis.com/dart-archive/channels/dev/release/latest/sdk/dartsdk-linux-x64-release.zip -O dartsdk-linux-x64-release.zip 

# Unpack the dart sdk
# sudo unzip -d / dartsdk-linux-x64-release.zip

# Make the sdk readable 
# sudo chmod -R go+rx /dart-sdk

# Add dart bin to global path
# sudo sh -c 'echo "export PATH=\$PATH:/dart-sdk/bin" >> /etc/profile'

# NOTE: only install squid for `daemon-isolate` images. 
# install squid3 for proxy
# sudo -s
# apt-get -y install squid3

# sed -i 's:#\(http_access allow localnet\):\1:' /etc/squid3/squid.conf
# sed -i 's:#\(http_access deny to_localhost\):\1:' /etc/squid3/squid.conf
# sed -i 's:#\(acl localnet src 10.0.0.0/8.*\):\1:' /etc/squid3/squid.conf
# sed -i 's:#\(acl localnet src 172.16.0.0/12.*\):\1:' /etc/squid3/squid.conf
# sed -i 's:#\(acl localnet src 192.168.0.0/16.*\):\1:' /etc/squid3/squid.conf
# sed -i 's:#\(acl localnet src fc00\:\:/7.*\):\1:' /etc/squid3/squid.conf
# sed -i 's:#\(acl localnet src fe80\:\:/10.*\):\1:' /etc/squid3/squid.conf

# cat <<EOF >>/etc/squid3/squid.conf
# acl to_metadata dst 169.254.169.254
# http_access deny to_metadata
# EOF

# service squid3 restart

# exit sudo -s
# exit

# TODO(adam): at this point if we have a stable repo we could git clone it so the image is baked. 

# Create the google compute engine image:
# sudo gcimagebundle -d /dev/sda -o /tmp/ --log_file=/tmp/create_image.log

# TODO(adam): replace the v1 with a version and/or date of build.

# Rename the image file:
# cd /tmp
# IMAGE_NAME=`ls *.image.tar.gz`
# sudo mv $IMAGE_NAME dart-engine-v1-$IMAGE_NAME

# Copy the image to cloud storage: 
# cd /tmp
# IMAGE_NAME=`ls *.image.tar.gz`
# gsutil cp $IMAGE_NAME gs://dart-carte-du-jour/images/

# Add the image to your compute engine project:
# cd /tmp
# IMAGE_NAME=`ls *.image.tar.gz`
# gcutil addimage dart-engine-v1 gs://dart-carte-du-jour/images/$IMAGE_NAME

