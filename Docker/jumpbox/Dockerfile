FROM debian:bookworm

RUN apt-get update && \
    apt-get -y install wget curl vim openssl git

COPY "../kubernetes-the-hard-way" "/kubernetes-the-hard-way"

WORKDIR "/kubernetes-the-hard-way"

RUN wget -q --https-only \
        --timestamping \
        -P downloads \
        -i downloads-$(dpkg --print-architecture).txt


RUN mkdir -p downloads/{client,cni-plugins,controller,worker}
RUN ARCH=$(dpkg --print-architecture) && \
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


RUN rm -rf downloads/*gz

RUN chmod +x downloads/{client,cni-plugins,controller,worker}/*

RUN cp downloads/client/kubectl /usr/local/bin/


