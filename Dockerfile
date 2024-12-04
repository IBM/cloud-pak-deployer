# Container image including olm-utils
ARG CPD_OLM_UTILS_V2_IMAGE="icr.io/cpopen/cpd/olm-utils-v2:latest"
ARG CPD_OLM_UTILS_V3_IMAGE="icr.io/cpopen/cpd/olm-utils-v3:latest"

FROM ${CPD_OLM_UTILS_V2_IMAGE} as olm-utils-v2
RUN cd /opt/ansible && \
    tar czf /tmp/opt-ansible-v2.tar.gz *

FROM ${CPD_OLM_UTILS_V3_IMAGE} as olmn-utils-v3

LABEL authors="Arthur Laimbock, \
            Markus Wiegleb, \
            Frank Ketelaars, \ 
            Jiri Petnik"

USER 0

# Install required packages, including HashiCorp Vault client
RUN yum install -y yum-utils && \
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    yum install -y tar sudo unzip wget jq skopeo httpd-tools git hostname bind-utils iproute procps-ng && \
    # Need gcc anf py-devel to recompile python dependencies on ppc64le (during pip install).
    yum install -y gcc python3.11-devel && \
    pip3 install jmespath pyyaml argparse python-benedict pyvmomi psutil && \
    sed -i 's|#!/usr/bin/python.*|#!/usr/bin/python3.9|g' /usr/bin/yum-config-manager && \
    yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo && \
    yum install -y vault && \
    yum install -y nginx && \
    yum clean all

RUN ansible-galaxy collection install community.crypto community.vmware kubernetes.core

VOLUME ["/Data"]

# Prepare directory that runs automation scripts
RUN mkdir -p /cloud-pak-deployer && \
    mkdir -p /Data && \
    mkdir -p /olm-utils

COPY . /cloud-pak-deployer/
COPY ./deployer-web/nginx.conf   /etc/nginx/

COPY --from=olm-utils-v2 /tmp/opt-ansible-v2.tar.gz /olm-utils/

RUN cd /opt/ansible && \
    tar czf /olm-utils/opt-ansible-v3.tar.gz *

# BUG with building wheel 
#RUN pip3 install -r /cloud-pak-deployer/deployer-web/requirements.txt > /tmp/deployer-web-pip-install.out 2>&1
RUN pip3 install "cython<3.0.0" wheel && pip3 install PyYAML==6.0 --no-build-isolation && pip3 install -r /cloud-pak-deployer/deployer-web/requirements.txt > /tmp/deployer-web-pip-install.out 2>&1

# cli utilities
RUN mkdir -p /Data/downloads && \ 
    wget -O /Data/downloads/cpd-cli.tar.gz $(curl -s https://api.github.com/repos/IBM/cpd-cli/releases/latest | jq -r '.assets[] | select( .browser_download_url | contains("linux-EE")).browser_download_url') && \
    tar -xvzf /Data/downloads/cpd-cli.tar.gz -C /usr/local/bin --strip-components=1 && \
    rm -rf /Data/downloads

ENV USER_UID=1001

RUN chown -R ${USER_ID}:0 /Data && \
    chown -R ${USER_ID}:0 /cloud-pak-deployer && \
    chmod -R ug+rwx /cloud-pak-deployer/docker-scripts && \
    chmod ug+rwx /cloud-pak-deployer/*.sh

# USER ${USER_UID}

ENTRYPOINT ["/cloud-pak-deployer/docker-scripts/container-bash.sh"]
