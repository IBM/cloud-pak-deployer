FROM quay.io/generic/centos8

LABEL authors="Arthur Laimbock <arthur.laimbock@nl.ibm.com>, \
            Markus Wiegleb <wieglebm@de.ibm.com>, \
            Frank Ketelaars <fketelaars@nl.ibm.com>"

# Install required packages, including HashiCorp Vault client
RUN yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo && \
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    yum install -y python3 python3-pip tar unzip wget jq yum-utils skopeo httpd-tools git && \
    yum install -y ansible && \
    pip3 install --upgrade pip pyyaml python-benedict pyvmomi && \
    alternatives --set python /usr/bin/python3 && \
    yum install -y vault && \
    yum clean all

RUN ansible-galaxy collection install community.general community.crypto ansible.utils community.vmware

# Install ibmcloud and plugins
RUN curl -fsSL https://clis.cloud.ibm.com/install/linux | sh && \
    ibmcloud plugin install kubernetes-service -f && \
    ibmcloud plugin install container-registry -f

VOLUME ["/Data"]

# Install Terraform
RUN TER_VER=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | \
        jq -r .tag_name | cut -dv -f2) && \
    wget -nv https://releases.hashicorp.com/terraform/${TER_VER}/terraform_${TER_VER}_linux_amd64.zip && \
    unzip terraform_${TER_VER}_linux_amd64.zip && \
    mv terraform /usr/local/bin/

# Install cloudctl
RUN CLOUDCTL_VER=$(curl -s https://api.github.com/repos/IBM/cloud-pak-cli/releases/latest | \
        jq -r .tag_name ) && \
    wget -nv https://github.com/IBM/cloud-pak-cli/releases/download/${CLOUDCTL_VER}/cloudctl-linux-amd64.tar.gz -P /tmp && \
    tar -xf /tmp/cloudctl-linux-amd64.tar.gz -C /usr/local/bin/ && \
    mv -f /usr/local/bin/cloudctl-linux-amd64 /usr/local/bin/cloudctl

# Prepare directory that runs automation scripts
RUN mkdir -p /cloud-pak-deployer && \
    mkdir -p /Data && \
    mkdir -p /tmp/config

COPY sample-configurations/web-ui-base-config/cloud-pak/cp4d.yaml /tmp/config/cp4d.yaml
COPY sample-configurations/web-ui-base-config/inventory /tmp/config/inventory
COPY sample-configurations/web-ui-base-config/ocp /tmp/config/config

COPY . /cloud-pak-deployer/

RUN chmod -R 755 /cloud-pak-deployer/docker-scripts && \
    chmod -R 755 /cloud-pak-deployer/*.sh

ENTRYPOINT ["/cloud-pak-deployer/docker-scripts/container-webui.sh"]
