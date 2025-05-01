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
    echo "Detected ARCH: $$ARCH" && \
    tar -xvf downloads/crictl-v1.32.0-linux-$${ARCH}.tar.gz -C downloads/worker/ && \
    tar -xvf downloads/containerd-2.1.0-beta.0-linux-$${ARCH}.tar.gz --strip-components 1 -C downloads/worker/ && \
    tar -xvf downloads/cni-plugins-linux-$${ARCH}-v1.6.2.tgz -C downloads/cni-plugins/ && \
    tar -xvf downloads/etcd-v3.6.0-rc.3-linux-$${ARCH}.tar.gz \
        -C downloads/ \
        --strip-components 1 \
        etcd-v3.6.0-rc.3-linux-$${ARCH}/etcdctl \
        etcd-v3.6.0-rc.3-linux-$${ARCH}/etcd && \
    ls -lh downloads/ && \
    mv downloads/etcdctl downloads/client/ && \
    mv downloads/kubectl downloads/client/ && \
    mv downloads/etcd downloads/controller/ && \
    mv downloads/kube-apiserver downloads/controller/ && \
    mv downloads/kube-controller-manager downloads/controller/ && \
    mv downloads/kube-scheduler downloads/controller/ && \
    mv downloads/kubelet downloads/worker/ && \
    mv downloads/kube-proxy downloads/worker/ && \
    mv downloads/runc.$${ARCH} downloads/worker/runc

rm -rf downloads/*gz

sudo chmod +x downloads/client/* && \
sudo chmod +x downloads/cni-plugins/* && \
sudo chmod +x downloads/controller/* && \
sudo chmod +x downloads/worker/*

sudo cp downloads/client/kubectl /usr/local/bin/

cat <<EOF > machines.txt
${server_ip} server.kubernetes.local server
${node0_ip} node-0.kubernetes.local node-0 10.200.0.0/24
${node1_ip} node-1.kubernetes.local node-1 10.200.1.0/24
EOF

ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N ""

while read IP FQDN HOST SUBNET; do
  ssh-copy-id root@$${IP}
done < machines.txt

while read IP FQDN HOST SUBNET; do
    CMD="sed -i 's/^127.0.1.1.*/127.0.1.1\t$${FQDN} $${HOST}/' /etc/hosts"
    ssh -n root@$${IP} "$$CMD"
    ssh -n root@$${IP} hostnamectl set-hostname $${HOST}
    ssh -n root@$${IP} systemctl restart systemd-hostnamed
done < machines.txt

echo "" > hosts
echo "# Kubernetes The Hard Way" >> hosts

while read IP FQDN HOST SUBNET; do
    ENTRY="$${IP} $${FQDN} $${HOST}"
    echo $$ENTRY >> hosts
done < machines.txt

sudo cat hosts >> /etc/hosts
