FROM registry.access.redhat.com/ubi9/ubi

LABEL authors="Frank Ketelaars"

# Install required packages
RUN yum install -y bind-utils git iproute make procps-ng python3.12 python3.12-pip
RUN ln -f -s /usr/bin/python3.12 /usr/bin/python3 && ln -f -s /usr/bin/pip3.12 /usr/bin/pip3

VOLUME ["/docs"]

COPY . /docs

RUN cd /docs && make venv

EXPOSE 8000

ENTRYPOINT ["/docs/run-doc-server.sh"]
