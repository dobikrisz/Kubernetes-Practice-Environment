# Kubernetes Environment Provisioned on GCP

## Introduction

This repository is an implementation of the [Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way) repository and automatically provision it to GCP via Compute Engine instances. I you are curious on the what or why, I highly recommend reading the original documentation.

This project simply deploys 4 Virtual Machines (jumpbox, server, node-0, node-1) and the supplementary resources (Networking, Service Account, Backend etc.) on the Cloud. You can use this deployment as-is (with minimal configuration to make it work in your environment) or you can edit it to fit your need.



create root password:

```
sudo passwd root
```

Login to root user:

```
su - root
```

Run

```
cd /kubernetes-the-hard-way/

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server=https://server.kubernetes.local:6443

kubectl config set-credentials admin \
  --client-certificate=admin.crt \
  --client-key=admin.key

kubectl config set-context kubernetes-the-hard-way \
  --cluster=kubernetes-the-hard-way \
  --user=admin

kubectl config use-context kubernetes-the-hard-way
```
