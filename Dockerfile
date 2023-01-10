# Container image including olm-utils
FROM registry.access.redhat.com/ubi8/ubi
FROM icr.io/cpopen/cpd/olm-utils:latest

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
    yum clean all

RUN ansible-galaxy collection install community.general community.crypto ansible.utils community.vmware

VOLUME ["/Data"]

# Prepare directory that runs automation scripts
RUN mkdir -p /cloud-pak-deployer && \
    mkdir -p /Data

COPY . /cloud-pak-deployer/
COPY ./deployer-web/nginx.conf   /etc/nginx/

RUN pip3 install -r /cloud-pak-deployer/deployer-web/requirements.txt > /tmp/deployer-web-pip-install.out 2>&1

ENV USER_UID=1001

RUN chown -R ${USER_ID}:0 /Data && \
    chown -R ${USER_ID}:0 /cloud-pak-deployer && \
    chmod -R ug+rwx /cloud-pak-deployer/docker-scripts && \
    chmod ug+rwx /cloud-pak-deployer/*.sh

# USER ${USER_UID}

ENTRYPOINT ["/cloud-pak-deployer/docker-scripts/container-bash.sh"]
