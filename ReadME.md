# Kubernetes Environment Provisioned on GCP

## Introduction

This repository is an implementation of the [Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way) repository and automatically provision it to GCP via Compute Engine instances. I you are curious on the what or why, I highly recommend reading the original documentation.

This project simply deploys 4 Virtual Machines (jumpbox, server, node-0, node-1) and the supplementary resources (Networking, Service Account, Backend etc.) on the Cloud. You can use this deployment as-is (with minimal configuration to make it work in your environment) or you can edit it to fit your need.

After deployment, you can manage the kubernetes cluster form the `jumpbox` VM after SSH into it. 

## Prequisities

### A GCP project with Billing

This requisite is pretty self-explanatory. This repo utilizes resources which cost money so a billing account must be set up. You can utilize the [300$ free credit](https://cloud.google.com/gcp?hl=en) Google offers for newly registered accounts

**Careful:** if managed incorrently, this project can get pretty expensive (in the range of 80-100$ /month) as Kubernetes requires quite large VM's to run effectively. You can play around with costs with using smaller VM's or selecting cheaper locations. You can also ensure safe spending by setting up alerts and billing budgets on your billing account.

### Workload Identity Federation

Authentication to GCP happens through WIF. Therefore it has to be set up before the project can be run. Note, that setting up WIF is not trivial the first time but explaining the ins-and-outs is out of the scope of this documentation. Please refer to the [Google Documentation](https://cloud.google.com/blog/products/identity-security/enabling-keyless-authentication-from-github-actions) on how to set up authentication.

### Service Account

You will need a service account to impersonate through the Workload Identity Federation. You will also need to assign some IAM roles to it on the project so it will be able to create the infrastructure. The minimal Predefined IAM roles are the following:

```
roles/compute.admin
roles/storage.admin
roles/secretmanager.admin
roles/iam.serviceAccountUser
roles/viewer
```

## Deployment

### Pipeline intro

This repo utilizes Github Actions in order to deploy the infrastructure. It is possible to transfer it to other CICD services, just modify the deployment configuration accordingly

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
