FROM registry.access.redhat.com/ubi9/ubi

LABEL authors="Frank Ketelaars"

# Install required packages
RUN yum install -y bind-utils git iproute make procps-ng python3 python3-pip

VOLUME ["/docs"]

COPY . /docs

RUN cd /docs && make venv

EXPOSE 8000

ENTRYPOINT ["/docs/run-doc-server.sh"]
