#! bin/bash

apt-get update && \
apt-get -y install wget curl vim openssl git

git clone --depth 1 \
  https://github.com/kelseyhightower/kubernetes-the-hard-way.git

cd kubernetes-the-hard-way

wget -q --https-only \
        --timestamping \
        -P downloads \
        -i downloads-$(dpkg --print-architecture).txt

mkdir -p downloads/client downloads/cni-plugins downloads/controller downloads/worker && \
    ARCH=$(dpkg --print-architecture) && \
    echo "Detected ARCH: $ARCH" && \
    tar -xvf downloads/crictl-v1.32.0-linux-${ARCH}.tar.gz -C downloads/worker/ && \
    tar -xvf downloads/containerd-2.1.0-beta.0-linux-${ARCH}.tar.gz --strip-components 1 -C downloads/worker/ && \
    tar -xvf downloads/cni-plugins-linux-${ARCH}-v1.6.2.tgz -C downloads/cni-plugins/ && \
    tar -xvf downloads/etcd-v3.6.0-rc.3-linux-${ARCH}.tar.gz \
        -C downloads/ \
        --strip-components 1 \
        etcd-v3.6.0-rc.3-linux-${ARCH}/etcdctl \
        etcd-v3.6.0-rc.3-linux-${ARCH}/etcd && \
    ls -lh downloads/ && \
    mv downloads/etcdctl downloads/client/ && \
    mv downloads/kubectl downloads/client/ && \
    mv downloads/etcd downloads/controller/ && \
    mv downloads/kube-apiserver downloads/controller/ && \
    mv downloads/kube-controller-manager downloads/controller/ && \
    mv downloads/kube-scheduler downloads/controller/ && \
    mv downloads/kubelet downloads/worker/ && \
    mv downloads/kube-proxy downloads/worker/ && \
    mv downloads/runc.${ARCH} downloads/worker/runc

rm -rf downloads/*gz

sudo chmod +x downloads/client/* && \
sudo chmod +x downloads/cni-plugins/* && \
sudo chmod +x downloads/controller/* && \
sudo chmod +x downloads/worker/*

sudo cp downloads/client/kubectl /usr/local/bin/

server_ip=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/server_ip" -H "Metadata-Flavor: Google")
node0_ip=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/node0_ip" -H "Metadata-Flavor: Google")
node1_ip=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/node1_ip" -H "Metadata-Flavor: Google")
public_key=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/ssh-keys" -H "Metadata-Flavor: Google")
private_key=$(gcloud secrets versions access latest --secret=ssh-private-key)

cat <<EOF > machines.txt
${server_ip} server.kubernetes.local server
${node0_ip} node-0.kubernetes.local node-0 10.200.0.0/24
${node1_ip} node-1.kubernetes.local node-1 10.200.1.0/24
EOF

mkdir /root/.ssh
sudo echo "${private_key}" > /root/.ssh/id_rsa
sudo chmod 700 /root/.ssh/id_rsa
sudo echo "${public_key}" > /root/.ssh/authorized_keys
sudo sed -i 's/^root://' /root/.ssh/authorized_keys
sudo chmod 600 /root/.ssh/authorized_keys

while read IP FQDN HOST SUBNET; do
    CMD="sed -i 's/^127.0.1.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts"
    ssh -o StrictHostKeyChecking=no -n root@${IP} "$CMD"
    ssh -o StrictHostKeyChecking=no -n root@${IP} hostnamectl set-hostname ${HOST}
    ssh -o StrictHostKeyChecking=no -n root@${IP} systemctl restart systemd-hostnamed
done < machines.txt

echo "" > hosts
echo "# Kubernetes The Hard Way" >> hosts

while read IP FQDN HOST SUBNET; do
    ENTRY="${IP} ${FQDN} ${HOST}"
    echo "$ENTRY" >> hosts
done < machines.txt

sudo cat hosts >> /etc/hosts

while read IP FQDN HOST SUBNET; do
    ssh-keyscan -H "${HOST} {$IP}" >> /root/.ssh/known_hosts
done < machines.txt

while read IP FQDN HOST SUBNET; do
  scp -o StrictHostKeyChecking=no hosts root@${HOST}:/root/
  ssh -o StrictHostKeyChecking=no -n \
    root@${HOST} "cat hosts >> /etc/hosts"
done < machines.txt


#-------------------------------------------- Provision Certificates ------------------------------------------------------

openssl genrsa -out ca.key 4096

openssl req -x509 -new -sha512 -noenc \
    -key ca.key -days 3653 \
    -config ca.conf \
    -out ca.crt

certs=(
  "admin" "node-0" "node-1"
  "kube-proxy" "kube-scheduler"
  "kube-controller-manager"
  "kube-api-server"
  "service-accounts"
)

for i in ${certs[@]}; do
  openssl genrsa -out "${i}.key" 4096

  openssl req -new -key "${i}.key" -sha256 \
    -config "ca.conf" -section ${i} \
    -out "${i}.csr"

  openssl x509 -req -days 3653 -in "${i}.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "${i}.crt"
done

for i in ${certs[@]}; do
  openssl genrsa -out "${i}.key" 4096

  openssl req -new -key "${i}.key" -sha256 \
    -config "ca.conf" -section ${i} \
    -out "${i}.csr"

  openssl x509 -req -days 3653 -in "${i}.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "${i}.crt"
done

for host in node-0 node-1; do
  ssh -o StrictHostKeyChecking=no root@${host} mkdir /var/lib/kubelet/

  scp -o StrictHostKeyChecking=no ca.crt root@${host}:/var/lib/kubelet/

  scp -o StrictHostKeyChecking=no ${host}.crt \
    root@${host}:/var/lib/kubelet/kubelet.crt

  scp -o StrictHostKeyChecking=no ${host}.key \
    root@${host}:/var/lib/kubelet/kubelet.key
done

scp -o StrictHostKeyChecking=no \
  ca.key ca.crt \
  kube-api-server.key kube-api-server.crt \
  service-accounts.key service-accounts.crt \
  root@server:/root/

#-------------------------------------------- Kubernetes Config Files ------------------------------------------------------

# The kubelet Kubernetes Configuration File
for host in node-0 node-1; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://server.kubernetes.local:6443 \
    --kubeconfig=${host}.kubeconfig

  kubectl config set-credentials system:node:${host} \
    --client-certificate=${host}.crt \
    --client-key=${host}.key \
    --embed-certs=true \
    --kubeconfig=${host}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${host} \
    --kubeconfig=${host}.kubeconfig

  kubectl config use-context default \
    --kubeconfig=${host}.kubeconfig
done

# The kube-proxy Kubernetes Configuration File
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server=https://server.kubernetes.local:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=kube-proxy.crt \
  --client-key=kube-proxy.key \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default \
  --kubeconfig=kube-proxy.kubeconfig

# The kube-controller-manager Kubernetes Configuration File
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server=https://server.kubernetes.local:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=kube-controller-manager.crt \
  --client-key=kube-controller-manager.key \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default \
  --kubeconfig=kube-controller-manager.kubeconfig

# The kube-scheduler Kubernetes Configuration File
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server=https://server.kubernetes.local:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=kube-scheduler.crt \
  --client-key=kube-scheduler.key \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default \
  --kubeconfig=kube-scheduler.kubeconfig

# The admin Kubernetes Configuration File
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=admin.crt \
  --client-key=admin.key \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default \
  --kubeconfig=admin.kubeconfig

# Distribute the Kubernetes Configuration Files
for host in node-0 node-1; do
  ssh -o StrictHostKeyChecking=no root@${host} "mkdir -p /var/lib/kube-proxy /var/lib/kubelet"

  scp -o StrictHostKeyChecking=no kube-proxy.kubeconfig \
    root@${host}:/var/lib/kube-proxy/kubeconfig \

  scp -o StrictHostKeyChecking=no ${host}.kubeconfig \
    root@${host}:/var/lib/kubelet/kubeconfig
done

scp -o StrictHostKeyChecking=no admin.kubeconfig \
  kube-controller-manager.kubeconfig \
  kube-scheduler.kubeconfig \
  root@server:/root/

#---------------------------------- Generating the Data Encryption Config and Key -----------------------------------------------

# The Encryption Key
export ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

# The Encryption Config File
envsubst < configs/encryption-config.yaml \
  > encryption-config.yaml

scp -o StrictHostKeyChecking=no encryption-config.yaml root@server:/root/

#---------------------------------------- Bootstrapping the etcd Cluster ---------------------------------------------------------

scp -o StrictHostKeyChecking=no \
  downloads/controller/etcd \
  downloads/client/etcdctl \
  units/etcd.service \
  root@server:/root/

ssh -o StrictHostKeyChecking=no root@server <<EOF
mv etcd etcdctl /usr/local/bin/
mkdir -p /etc/etcd /var/lib/etcd
chmod 700 /var/lib/etcd
cp ca.crt kube-api-server.key kube-api-server.crt \
  /etc/etcd/
mv etcd.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
EOF

#--------------------------------------- Bootstrapping the Kubernetes Control Plane -----------------------------------------------

scp -o StrictHostKeyChecking=no \
  downloads/controller/kube-apiserver \
  downloads/controller/kube-controller-manager \
  downloads/controller/kube-scheduler \
  downloads/client/kubectl \
  units/kube-apiserver.service \
  units/kube-controller-manager.service \
  units/kube-scheduler.service \
  configs/kube-scheduler.yaml \
  configs/kube-apiserver-to-kubelet.yaml \
  root@server:/root/

# Provision the Kubernetes Control Plane
ssh -o StrictHostKeyChecking=no root@server <<EOF
mkdir -p /etc/kubernetes/config
mv kube-apiserver \
  kube-controller-manager \
  kube-scheduler kubectl \
  /usr/local/bin/
mkdir -p /var/lib/kubernetes/
mv ca.crt ca.key \
  kube-api-server.key kube-api-server.crt \
  service-accounts.key service-accounts.crt \
  encryption-config.yaml \
  /var/lib/kubernetes/
mv kube-apiserver.service \
  /etc/systemd/system/kube-apiserver.service
mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
mv kube-controller-manager.service /etc/systemd/system/
mv kube-scheduler.kubeconfig /var/lib/kubernetes/
mv kube-scheduler.yaml /etc/kubernetes/config/
mv kube-scheduler.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable kube-apiserver \
  kube-controller-manager kube-scheduler
systemctl start kube-apiserver \
  kube-controller-manager kube-scheduler
EOF

# RBAC for Kubelet Authorization
ssh -o StrictHostKeyChecking=no root@server <<EOF
kubectl apply -f kube-apiserver-to-kubelet.yaml \
  --kubeconfig admin.kubeconfig
EOF

#--------------------------------------- Bootstrapping the Kubernetes Worker Nodes -----------------------------------------------

for HOST in node-0 node-1; do
  SUBNET=$(grep ${HOST} machines.txt | cut -d " " -f 4)
  sed "s|SUBNET|$SUBNET|g" \
    configs/10-bridge.conf > 10-bridge.conf

  sed "s|SUBNET|$SUBNET|g" \
    configs/kubelet-config.yaml > kubelet-config.yaml

  scp 10-bridge.conf kubelet-config.yaml \
  root@${HOST}:/root/
done

for HOST in node-0 node-1; do
  scp \
    downloads/worker/* \
    downloads/client/kubectl \
    configs/99-loopback.conf \
    configs/containerd-config.toml \
    configs/kube-proxy-config.yaml \
    units/containerd.service \
    units/kubelet.service \
    units/kube-proxy.service \
    root@${HOST}:/root/
done

for HOST in node-0 node-1; do
  scp \
    downloads/cni-plugins/* \
    root@${HOST}:/root/cni-plugins/
done

# Provisioning a Kubernetes Worker Node
for HOST in node-0 node-1; do
  ssh -o StrictHostKeyChecking=no root@${HOST} <<EOF
  mv crictl kube-proxy kubelet runc \
    /usr/local/bin/
  mv containerd containerd-shim-runc-v2 containerd-stress /bin/
  mv cni-plugins/* /opt/cni/bin/
  mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/
  modprobe br-netfilter
  echo "br-netfilter" >> /etc/modules-load.d/modules.conf
  echo "net.bridge.bridge-nf-call-iptables = 1" \
    >> /etc/sysctl.d/kubernetes.conf
  echo "net.bridge.bridge-nf-call-ip6tables = 1" \
    >> /etc/sysctl.d/kubernetes.conf
  sysctl -p /etc/sysctl.d/kubernetes.conf
  mkdir -p /etc/containerd/
  mv containerd-config.toml /etc/containerd/config.toml
  mv containerd.service /etc/systemd/system/
  mv kubelet-config.yaml /var/lib/kubelet/
  mv kubelet.service /etc/systemd/system/
  mv kube-proxy-config.yaml /var/lib/kube-proxy/
  mv kube-proxy.service /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable containerd kubelet kube-proxy
  systemctl start containerd kubelet kube-proxy
EOF
done

#---------------------------------------- Provisioning Pod Network Routes -----------------------------------------------

SERVER_IP=$(grep server machines.txt | cut -d " " -f 1)
NODE_0_IP=$(grep node-0 machines.txt | cut -d " " -f 1)
NODE_0_SUBNET=$(grep node-0 machines.txt | cut -d " " -f 4)
NODE_1_IP=$(grep node-1 machines.txt | cut -d " " -f 1)
NODE_1_SUBNET=$(grep node-1 machines.txt | cut -d " " -f 4)

ssh root@server <<EOF
  ip route add ${NODE_0_SUBNET} via ${NODE_0_IP}
  ip route add ${NODE_1_SUBNET} via ${NODE_1_IP}
EOF

ssh root@node-0 <<EOF
  ip route add ${NODE_1_SUBNET} via ${NODE_1_IP}
EOF

ssh root@node-1 <<EOF
  ip route add ${NODE_0_SUBNET} via ${NODE_0_IP}
EOF

