#! bin/bash

sudo sed -i \
  's/^#*PermitRootLogin.*/PermitRootLogin yes/' \
  /etc/ssh/sshd_config

public_key=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/ssh-keys" -H "Metadata-Flavor: Google")
sudo echo "${public_key}" > /root/.ssh/authorized_keys
sudo chmod 600 /root/.ssh/authorized_keys

systemctl restart sshd