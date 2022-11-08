FROM registry.access.redhat.com/ubi8/ubi

LABEL authors="Frank Ketelaars"

ARG NVM_RELEASE=14.15

# Install required packages
RUN yum install -y git && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash && \
    source ~/.bashrc && \
    nvm install ${NVM_RELEASE} && \
    nvm use ${NVM_RELEASE} 

VOLUME ["/doc"]

COPY . /doc

EXPOSE 8080

ENTRYPOINT ["/doc/run-npm-dev.sh"]
