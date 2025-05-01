#! bin/bash

sudo sed -i \
  's/^#*PermitRootLogin.*/PermitRootLogin yes/' \
  /etc/ssh/sshd_config

mkdir /root/.ssh
public_key=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/ssh-keys" -H "Metadata-Flavor: Google")
sudo echo "${public_key}" > /root/.ssh/authorized_keys
sudo sed -i 's/^root://' /root/.ssh/authorized_keys
sudo chmod 600 /root/.ssh/authorized_keys

sudo systemctl restart sshd