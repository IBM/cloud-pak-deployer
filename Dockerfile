# Container image including olm-utils
ARG CPD_OLM_UTILS_V1_IMAGE
ARG CPD_OLM_UTILS_V2_IMAGE

FROM registry.access.redhat.com/ubi8/ubi

FROM ${CPD_OLM_UTILS_V1_IMAGE} as olm-utils-v1

RUN cd /opt/ansible && \
    tar czf /tmp/opt-ansible-v1.tar.gz *

FROM ${CPD_OLM_UTILS_V2_IMAGE}

LABEL authors="Arthur Laimbock, \
            Markus Wiegleb, \
            Frank Ketelaars, \ 
            Jiri Petnik"

USER 0

# Install required packages, including HashiCorp Vault client
RUN yum install -y yum-utils python38 python38-pip && \
    yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo && \
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    yum install -y tar sudo unzip wget jq skopeo httpd-tools git hostname bind-utils iproute procps-ng && \
    pip3 install --upgrade pip && \
    pip3 install jmespath pyyaml argparse python-benedict pyvmomi psutil && \
    alternatives --set python /usr/bin/python3 && \
    yum install -y vault && \
    yum install -y nginx && \
    curl -O https://download.java.net/java/GA/jdk9/9/binaries/openjdk-9_linux-x64_bin.tar.gz && \
    tar -xvf openjdk-9_linux-x64_bin.tar.gz -C /usr && \
    ln -fs /usr/jdk-9/bin/java /usr/bin/java && \
    ln -fs /usr/jdk-9/bin/keytool /usr/bin/keytool && \
    rm -f openjdk-9_linux-x64_bin.tar.gz && \
    curl -O https://get.helm.sh/helm-v3.6.0-linux-amd64.tar.gz && \
    tar -zxvf helm-v3.6.0-linux-amd64.tar.gz linux-amd64/helm && \
    mv linux-amd64/helm helm && \
    rm -f helm-v3.6.0-linux-amd64.tar.gz && \
    chmod u+x helm && \
    mv helm /usr/bin/ && \
    yum clean all

RUN ansible-galaxy collection install community.general community.crypto ansible.utils community.vmware kubernetes.core

VOLUME ["/Data"]

# Prepare directory that runs automation scripts
RUN mkdir -p /cloud-pak-deployer && \
    mkdir -p /Data && \
    mkdir -p /olm-utils

COPY . /cloud-pak-deployer/
COPY ./deployer-web/nginx.conf   /etc/nginx/

COPY --from=olm-utils-v1 /tmp/opt-ansible-v1.tar.gz /olm-utils/

RUN cd /opt/ansible && \
    tar czf /olm-utils/opt-ansible-v2.tar.gz *

RUN pip3 install -r /cloud-pak-deployer/deployer-web/requirements.txt > /tmp/deployer-web-pip-install.out 2>&1

ENV USER_UID=1001

RUN chown -R ${USER_ID}:0 /Data && \
    chown -R ${USER_ID}:0 /cloud-pak-deployer && \
    chmod -R ug+rwx /cloud-pak-deployer/docker-scripts && \
    chmod ug+rwx /cloud-pak-deployer/*.sh

# USER ${USER_UID}

ENTRYPOINT ["/cloud-pak-deployer/docker-scripts/container-bash.sh"]
