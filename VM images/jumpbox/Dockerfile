FROM debian:bookworm

RUN apt-get update && \
    apt-get -y install wget curl vim openssl git

COPY "../kubernetes-the-hard-way" "/kubernetes-the-hard-way"

WORKDIR "/kubernetes-the-hard-way"

RUN wget -q --https-only \
        --timestamping \
        -P downloads \
        -i downloads-$(dpkg --print-architecture).txt


RUN export ARCH=$(dpkg --print-architecture)
RUN mkdir -p downloads/{client,cni-plugins,controller,worker}
RUN tar -xvf downloads/crictl-v1.32.0-linux-${ARCH}.tar.gz \
        -C downloads/worker/
RUN tar -xvf downloads/containerd-2.1.0-beta.0-linux-${ARCH}.tar.gz \
        --strip-components 1 \
        -C downloads/worker/
RUN tar -xvf downloads/cni-plugins-linux-${ARCH}-v1.6.2.tgz \
        -C downloads/cni-plugins/
RUN tar -xvf downloads/etcd-v3.6.0-rc.3-linux-${ARCH}.tar.gz \
        -C downloads/ \
        --strip-components 1 \
        etcd-v3.6.0-rc.3-linux-${ARCH}/etcdctl \
        etcd-v3.6.0-rc.3-linux-${ARCH}/etcd
RUN mv downloads/{etcdctl,kubectl} downloads/client/
RUN mv downloads/{etcd,kube-apiserver,kube-controller-manager,kube-scheduler} \
        downloads/controller/
RUN mv downloads/{kubelet,kube-proxy} downloads/worker/
RUN mv downloads/runc.${ARCH} downloads/worker/runc

RUN rm -rf downloads/*gz

RUN chmod +x downloads/{client,cni-plugins,controller,worker}/*

RUN cp downloads/client/kubectl /usr/local/bin/


