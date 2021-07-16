#!/bin/bash

# Licensed Materials - Property of IBM
# Copyright IBM Corporation 2020. All Rights Reserved
# US Government Users Restricted Rights -
# Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# This is an internal component, bundled with an official IBM product. 
# Please refer to that particular license for additional information. 

# ---------- Command arguments ----------

# registry server
AUTH_REGISTRY_SERVER=

# username for registry authentication
AUTH_REGISTRY_USERNAME=

# password for registry authentication
AUTH_REGISTRY_PASSWORD=

# email for registry authentication
AUTH_REGISTRY_EMAIL=

# the CASE archive directory
CASE_ARCHIVE_DIR=

# the CASE archive name
CASE_ARCHIVE=

# dry-run mode
DRY_RUN=

# show registries
SHOW_REGISTRIES=

# show registries and namespaces
SHOW_REGISTRIES_NAMESPACES=

# source image
IMAGE=

# image CSV file
IMAGE_CSV_FILE=

# image content source policy name
IMAGE_POLICY_NAME=

# the source image registry
SOURCE_REGISTRY=

# the target image registry
TARGET_REGISTRY=

# the image groups to filter from mirror
IMAGE_GROUPS=

# skips using image delta if it exists
SKIP_DELTA=

# Boolean toggle to determine if the command called was for mirroring images or not
IMAGE_MIRROR_ACTION_CALLED=

# ---------- Command variables ----------

# data path that keeps the registry authentication secrets
AUTH_DATA_PATH="${XDG_RUNTIME_DIR}/containers"

# namespace action for image mirroring
NAMESPACE_ACTION=

# namespace action value for image mirroring
NAMESPACE_ACTION_VALUE=

# temporary file prefix
OC_TMP_PREFIX="airgap"

# temporary case directory
OC_TMP_CASE_DIR=$(mktemp /tmp/${OC_TMP_PREFIX}_case_XXXXXXXXX)

# temporary csv directory
OC_TMP_CSV_DIR=$(mktemp /tmp/${OC_TMP_PREFIX}_csv_XXXXXXXXX)

# temporary image mapping file
OC_TMP_IMAGE_MAP=$(mktemp /tmp/${OC_TMP_PREFIX}_image_mapping_XXXXXXXXX)

# temporary image mapping file split size
OC_TMP_IMAGE_MAP_SPLIT_SIZE=100

# temporary image content source policy taml
OC_TMP_IMAGE_POLICY=$(mktemp /tmp/${OC_TMP_PREFIX}_image_policy_XXXXXXXXX)

# temporary cluster pull secret
OC_TMP_PULL_SECRET=$(mktemp /tmp/${OC_TMP_PREFIX}_pull_secret_XXXXXXXXX)

# script directory
SCRIPT_DIR=`dirname "$0"`

# script version
VERSION=0.12.3

# --- registry service variables ---

# container engine used to run the registry, either 'docker' or 'podman'
CONTAINER_ENGINE=

# docker registry image
REGISTRY_IMAGE=docker.io/library/registry:2.6

# registry directory
REGISTRY_DIR=/tmp/docker-registry

# registry container name
REGISTRY_NAME=docker-registry

# registry service host
REGISTRY_HOST=$(hostname -f)

# registry service port
REGISTRY_PORT=5000

# registry default account username
REGISTRY_USERNAME=

# registry default account password
REGISTRY_PASSWORD=

# indicates if the registry default account password is generated or not
REGISTRY_PASSWORD_GENERATED=false

# registry reset
REGISTRY_RESET=false

# registry self-sign TLS certificate authority subject
REGISTRY_TLS_CA_SUBJECT="/C=US/ST=New York/L=Armonk/O=IBM Cloud Pak/CN=IBM Cloud Pak Root CA"

# registry self-sign TLS certificate subject
REGISTRY_TLS_CERT_SUBJECT="/C=US/ST=New York/L=Armonk/O=IBM Cloud Pak"

# registry self-sign TLS certificate subject alternative name
REGISTRY_TLS_CERT_SUBJECT_ALT_NAME="subjectAltName=IP:127.0.0.1,DNS:localhost"

# indicates if registry is TLS enabled
REGISTRY_TLS_ENABLED=true

# registry certificate authorities configmap
REGISTRY_CA_CONFIGMAP=airgap-trusted-ca

# ---------- Shared Package Variables ----------
# Context of mirrored image CSV files created
declare -a MIRRORED_IMAGE_CSV_CONTEXT=


# ---------- Command functions ----------

#
# Main function
#
main() {
    # clean up previous temp files
    find -L /tmp -type f -name "${OC_TMP_PREFIX}_*" 2> /dev/null -exec rm -f {} 2> /dev/null \;

    # parses command arguments
    parse_arguments "$@"
}

#
# Parses the CLI arguments
#
parse_arguments() {
    if [[ "$#" == 0 ]]; then
        print_usage
        exit 1
    fi

    # process options
    while [[ "$1" != "" ]]; do
        case "$1" in
        registry)
            shift
            parse_registry_arguments "$@"
            break
            ;;
        image)
            shift
            parse_image_arguments "$@"
            break
            ;;
        cluster)
            shift
            parse_cluster_arguments "$@"
            break
            ;;
        -v | --version)
            print_version
            exit 1
            ;;       
        -h | --help)
            print_usage
            exit 1
            ;;
        *)
            print_usage
            exit 1
            ;;
        esac
        shift
    done
}

#
# Prints usage menu
#
print_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} [registry|image|cluster]"
    echo ""
    echo "This tool helps mirroring CASE images and updating cluster to support"
    echo "installing IBM Cloud Pak in an Air-Gapped environment"
    echo ""
    echo "Options:"
    echo "   registry          Manage registry authentication secrets"
    echo "   image             Mirroring images from one registry to another"
    echo "   cluster           Configure OpenShift cluster to use with a mirrored registry"
    echo "   -v, --version     Print version information"
    echo "   -h, --help        Print usage information"
    echo ""
}

#
# Prints version 
#
print_version() {
    echo "[INFO] Version ${VERSION}"
}

# ---------- Registry functions ----------

#
# Parses argument for 'registry' action
#
parse_registry_arguments() {
    if [[ "$#" == 0 ]]; then
        print_registry_usage
        exit 1
    fi

     # process options
    while [ "$1" != "" ]; do
        case "$1" in
        service)
            shift
            parse_registry_service_arguments "$@"
            break
            ;;
        secret)
            shift
            parse_registry_secret_arguments "$@"
            break
            ;;
        -h | --help)
            print_registry_usage
            exit 1
            ;;
        *)
            print_registry_usage
            exit 1
            ;;
        esac
        shift
    done
}

# Prints usage menu for 'registry' action
#
print_registry_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} registry [service|secret] [OPTIONS]..."
    echo ""
    echo "Run a private docker registry or manage authentication secrets" 
    echo "for all theregistries used in the image mirroring process."
    echo ""
    echo "Options:"
    echo "  service"
    echo "    init               Initialize a docker registry"
    echo "    start              Start a docker registry service"
    echo "    stop               Stop the running docker registry service"
    echo "  secret"
    echo "    -c, --create       Create an authentication secret"
    echo "    -d, --delete       Delete an authentication secret"
    echo "    -l, --list         List all authentication secrets"
    echo "    -D, --delete-all   Delete all authentication secrets"
    echo "  -h, --help           Print usage information"
    echo ""
}

# ---------- Registry service functions ----------

#
# Initializes docker registry
#
do_registry_service_init() {
    # parses arguments
    parse_registry_service_init_arguments "$@"
    
    # validates arguments
    validate_registry_service_init_arguments

    # validates required tools
    validate_registry_service_init_required_tools
    
    # deletes existing auth directory

    # initializes registry data directory
    echo "[INFO] Initializing ${REGISTRY_DIR}/data"
    if [ "${REGISTRY_RESET}" == "true" ] && [ -d "${REGISTRY_DIR}/data}" ]; then
        rm -rf "${REGISTRY_DIR}/data}"
    fi
    mkdir -p "${REGISTRY_DIR}/data"

    # initializes registry auth directory
    echo "[INFO] Initializing ${REGISTRY_DIR}/auth"
    if [ -d "${REGISTRY_DIR}/auth" ]; then
        rm -rf "${REGISTRY_DIR}/auth"
    fi
    mkdir -p "${REGISTRY_DIR}/auth"

    # creates registry certs directory
    echo "[INFO] Initializing ${REGISTRY_DIR}/certs"
    if [ -d "${REGISTRY_DIR}/certs" ]; then
        rm -rf "${REGISTRY_DIR}/certs"
    fi
    mkdir -p "${REGISTRY_DIR}/certs"

    if [ ! -z "${REGISTRY_USERNAME}" ] && [ ! -z "${REGISTRY_PASSWORD}" ]; then
        # creates htpasswd and add a default account
        echo "[INFO] Creating ${REGISTRY_DIR}/auth/htpasswd"
        htpasswd -bBc "${REGISTRY_DIR}/auth/htpasswd" ${REGISTRY_USERNAME} ${REGISTRY_PASSWORD}
    fi

    # prepares for subject subject alternative name
    if [[ ! "${REGISTRY_TLS_CERT_SUBJECT}" =~ .*"CN=".* ]]; then
        REGISTRY_TLS_CERT_SUBJECT="${REGISTRY_TLS_CERT_SUBJECT}/CN=${REGISTRY_HOST}"
    fi

    # records the registry hostname
    if [ ! -z "${REGISTRY_HOST}" ]; then
        echo "${REGISTRY_HOST}" > "${REGISTRY_DIR}/hostname"
    fi

    # prepares for subject alternative name
    if [[ "${REGISTRY_HOST}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        REGISTRY_TLS_CERT_SUBJECT_ALT_NAME="${REGISTRY_TLS_CERT_SUBJECT_ALT_NAME},IP:${REGISTRY_HOST}"
    else
        REGISTRY_TLS_CERT_SUBJECT_ALT_NAME="${REGISTRY_TLS_CERT_SUBJECT_ALT_NAME},DNS:${REGISTRY_HOST}"
    fi

    # generates self-sign certificate
    echo "[INFO] Generating self-sign certificate"
    openssl genrsa -out "${REGISTRY_DIR}/certs/ca.key" 4096
    openssl req -new -x509 -days 365 -sha256 -subj "${REGISTRY_TLS_CA_SUBJECT}" -key "${REGISTRY_DIR}/certs/ca.key" -out "${REGISTRY_DIR}/certs/ca.crt"
    openssl req -newkey rsa:4096 -nodes -subj "${REGISTRY_TLS_CERT_SUBJECT}" -keyout "${REGISTRY_DIR}/certs/server.key" -out "${REGISTRY_DIR}/certs/server.csr"
    openssl x509 -req -days 365 -sha256 -extfile <(printf "${REGISTRY_TLS_CERT_SUBJECT_ALT_NAME}") \
        -CAcreateserial -CA "${REGISTRY_DIR}/certs/ca.crt" -CAkey "${REGISTRY_DIR}/certs/ca.key" \
        -in "${REGISTRY_DIR}/certs/server.csr"   -out "${REGISTRY_DIR}/certs/server.crt"

    if [[ "${REGISTRY_PASSWORD_GENERATED}" == "true" ]]; then
        echo "[INFO] username = ${REGISTRY_USERNAME}"
        echo "[INFO] password = ${REGISTRY_PASSWORD}"
    fi
}

#
# Starts the docker registry
#
do_registry_service_start() {
    # parses arguments
    parse_registry_service_start_arguments "$@"

    # validates arguments
    validate_registry_service_start_arguments

    # detects available container engine
    detect_registry_service_container_engine

    # starts registry container
    echo "[INFO] Starting registry"
    if [ -f "${REGISTRY_DIR}/auth/htpasswd" ]; then
        ${CONTAINER_ENGINE} run --name "${REGISTRY_NAME}" -p ${REGISTRY_PORT}:5000 --restart=always \
            -v ${REGISTRY_DIR}/data:/var/lib/registry:z \
            -v ${REGISTRY_DIR}/auth:/auth:z \
            -v ${REGISTRY_DIR}/certs:/certs:z \
            -e REGISTRY_AUTH=htpasswd \
            -e REGISTRY_AUTH_HTPASSWD_REALM=RegistryRealm \
            -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
            -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/server.crt \
            -e REGISTRY_HTTP_TLS_KEY=/certs/server.key \
            -d ${REGISTRY_IMAGE}
    else
        ${CONTAINER_ENGINE} run --name "${REGISTRY_NAME}" -p ${REGISTRY_PORT}:5000 --restart=always \
            -v ${REGISTRY_DIR}/data:/var/lib/registry:z \
            -v ${REGISTRY_DIR}/auth:/auth:z \
            -v ${REGISTRY_DIR}/certs:/certs:z \
            -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/server.crt \
            -e REGISTRY_HTTP_TLS_KEY=/certs/server.key \
            -d ${REGISTRY_IMAGE}
    fi

    # checks for return code
    if [[ "$?" -ne 0 ]]; then
        exit 11
    fi

    # grabs the container id
    container_id=$(${CONTAINER_ENGINE} ps -qf "name=${REGISTRY_NAME}")
    if [ ! -z "${container_id}" ]; then
        echo "[INFO] Registry service started at ${REGISTRY_HOST}:${REGISTRY_PORT}"
    else
        echo "[ERROR] Registry service cannot be started"
        exit 11
    fi
}

#
# Stops the docker registry
#
do_registry_service_stop() {
    # parses arguments
    parse_registry_service_stop_arguments "$@"

    # validates arguments
    validate_registry_service_stop_arguments

    # detects available container engine
    detect_registry_service_container_engine

    # grabs the container id
    container_id=$(${CONTAINER_ENGINE} ps -aqf "name=${REGISTRY_NAME}")

    # checks for return code
    if [[ "$?" -ne 0 ]]; then
        exit 11
    fi

    if [ ! -z "${container_id}" ]; then
        echo "[INFO] Stopping registry service"
        ${CONTAINER_ENGINE} stop ${container_id}
        ${CONTAINER_ENGINE} rm ${container_id}
        echo "[INFO] Registry service stopped"
    else
        echo "[WARN] Registry service already stopped"
    fi
}

#
# Detects available supported container command, such as 'docker' or 'podman'
#
detect_registry_service_container_engine() {
    docker_command=$(command -v docker 2> /dev/null)
    podman_command=$(command -v podman 2> /dev/null)

    if [ ! -z "${CONTAINER_ENGINE}" ]; then
        # handles when container engine is explicitly specified
        if [ "${CONTAINER_ENGINE}" == "podman" ] && [ -x "${podman_command}" ]; then
            CONTAINER_ENGINE=${podman_command}
        elif [ "${CONTAINER_ENGINE}" == "docker" ] && [ -x "${docker_command}" ]; then
            CONTAINER_ENGINE=${docker_command}
        else
            echo "[ERROR] ${CONTAINER_ENGINE} not available on the system"
            exit 1
        fi
    else
        # auto detect available container engine
        if [ -x "${podman_command}" ]; then
            CONTAINER_ENGINE=${podman_command}
        elif [ -x "${docker_command}" ]; then
            CONTAINER_ENGINE=${docker_command}        
        else
            echo "[ERROR] docker or podman must be available on the system"
            exit 1
        fi
    fi

    echo "[INFO] Container engine: ${CONTAINER_ENGINE}"
}

#
# Parses arguments for 'registry service' action
#
parse_registry_service_arguments() {
    if [[ "$#" == 0 ]]; then
        print_registry_service_usage
        exit 1
    fi

    while [[ "$1" != "" ]]; do
        case "$1" in
        init)
            shift
            do_registry_service_init "$@"
            break
            ;;
        start)
            shift
            do_registry_service_start "$@"
            break
            ;;
        stop)
            shift
            do_registry_service_stop "$@"
            break
            ;;
        -h | --help)
            print_registry_service_usage
            exit 1
            ;;
        *)
            print_registry_service_usage
            exit 1
            ;;
        esac
        shift
    done
}

#
# Parses arguments for 'registry service init' action
#
parse_registry_service_init_arguments() {
    # process options
    while [[ "$1" != "" ]]; do
        case "$1" in
        -d | --dir)
            shift
            REGISTRY_DIR="$1"
            ;;
        -u | --username)
            shift
            REGISTRY_USERNAME="$1"
            ;;
        -p | --password)
            shift
            REGISTRY_PASSWORD="$1"
            ;;
        -s | --subject)
            shift
            REGISTRY_TLS_CERT_SUBJECT="$1"
            ;;
        -r | --registry)
            shift
            REGISTRY_HOST="$1"
            ;;
        -c | --clean)
            REGISTRY_RESET=true
            ;;
        -h | --help)
            print_registry_service_init_usage
            exit 1
            ;;
        *)
            print_registry_service_init_usage
            exit 1
            ;;
        esac
        shift
    done
}

#
# Parses arguments for 'registry service start' action
#
parse_registry_service_start_arguments() {
    # process options
    while [[ "$1" != "" ]]; do
        case "$1" in
        -p | --port)
            shift
            REGISTRY_PORT="$1"
            ;;
        -d | --dir)
            shift
            REGISTRY_DIR="$1"
            ;;
        -e | --engine)
            shift
            CONTAINER_ENGINE="$1"
            ;;
        -i | --image)
            shift
            REGISTRY_IMAGE="$1"
            ;;
        -h | --help)
            print_registry_service_start_usage
            exit 1
            ;;
        *)
            print_registry_service_start_usage
            exit 1
            ;;
        esac
        shift
    done
}

#
# Parses arguments for 'registry service stop' action
#
parse_registry_service_stop_arguments() {
    # process options
    while [[ "$1" != "" ]]; do
        case "$1" in
        -e | --engine)
            shift
            CONTAINER_ENGINE="$1"
            ;;
        -h | --help)
            print_registry_service_stop_usage
            exit 1
            ;;
        *)
            print_registry_service_stop_usage
            exit 1
            ;;
        esac
        shift
    done
}

#
# Prints usage menu for 'registry service' action
#
print_registry_service_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} registry service [init|start|stop]"
    echo ""
    echo "A helper to intialize, start and stop a docker registry"
    echo ""
    echo "Options:"
    echo "   init         Initialize a docker registry"
    echo "   start        Start a docker registry"
    echo "   stop         Stop a running docker registry"
    echo "   -h, --help   Print usage information"
    echo ""
}

#
# Prints usage menu for 'registry service init' action
#
print_registry_service_init_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} registry service init [-u USERNAME] [-p PASSWORD] [OPTIONS]..."
    echo ""
    echo "Configure a docker registry with self-sign certificate"
    echo ""
    echo "Options:"
    echo "   -u, --username string   Default registry user account"
    echo "   -p, --password string   Default registry user password"
    echo "   -d, --dir string        Local directory for the docker registry. Default is /tmp/docker-registry"
    echo "   -s  --subject string    Self-sign TLS certificate subject"
    echo "   -r  --registry string   IP or FQDN for the docker registry. Default is local hostname"
    echo "   -c  --clean             Clean up all existing repositories data"
    echo "   -h, --help              Print usage information"
    echo ""
}

#
# Prints usage menu for 'registry service start' action
#
print_registry_service_start_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} registry service start [OPTIONS]..."
    echo ""
    echo "Start a docker registry container"
    echo ""
    echo "Options:"
    echo "   -p, --port number     Image registry service port. Default is 5000"
    echo "   -d, --dir string      Local directory for the docker registry. Default is ${REGISTRY_DIR}"
    echo "   -e, --engine string   Container engine to run the container. Either 'podman' or 'docker'"
    echo "                         If not specified, it will be detected automatically"
    echo "   -i, --image string    Docker registry image. Default is ${REGISTRY_IMAGE}"
    echo "   -h, --help            Print usage information"
    echo ""
}

#
# Prints usage menu for 'registry service stop' action
#
print_registry_service_stop_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} registry service stop [OPTIONS]..."
    echo ""
    echo "Stop a running docker registry container"
    echo ""
    echo "Options:"
    echo "   -e, --engine string   Container engine used to start the container. Either 'podman' or 'docker'."
    echo "                         If not specified, it will be detected automatically"
    echo "   -h, --help            Print usage information"
    echo ""
}

#
# Validates arguments for 'registry service init' action
#
validate_registry_service_init_arguments() {
    if [ -z "${REGISTRY_DIR}" ]; then
        echo "[ERROR] Registry directory not specified"
        exit 1
    fi

    if [ -z "${REGISTRY_USERNAME}" ]; then
        REGISTRY_USERNAME=admin
    fi

    if [ -z "${REGISTRY_PASSWORD}" ]; then
        REGISTRY_PASSWORD=$(openssl rand -hex 16)
        REGISTRY_PASSWORD_GENERATED=true
    fi

    if [ -z "${REGISTRY_TLS_CERT_SUBJECT}" ]; then
        echo "[ERROR] Registry TLS certificate subject not specified"
        exit 1
    fi
}

#
# Validates arguments for 'registry service start' action
#
validate_registry_service_start_arguments() {
    if [ ! -d "${REGISTRY_DIR}" ]; then
        echo "[ERROR] Registry directory not found: ${REGISTRY_DIR}"
        exit 1
    fi

    if [ ! -d "${REGISTRY_DIR}/data" ]; then
        echo "[ERROR] Registry data directory not found: ${REGISTRY_DIR}/data"
        exit 1
    fi

    if [ ! -f "${REGISTRY_DIR}/certs/server.crt" ]; then
        echo "[ERROR] Missing registry TLS certificate: ${REGISTRY_DIR}/certs/server.crt"
        exit 1
    fi

    if [ ! -f "${REGISTRY_DIR}/certs/server.key" ]; then
        echo "[ERROR] Missing registry TLS private key: ${REGISTRY_DIR}/certs/server.key"
        exit 1
    fi

    if [ ! -f "${REGISTRY_DIR}/hostname" ]; then
        REGISTRY_SERVER=$(cat "${REGISTRY_DIR}/hostname}")
    fi

    if [ ! -z "${CONTAINER_ENGINE}" ]; then
        if [ "${CONTAINER_ENGINE}" != "podman" ] && [ "${CONTAINER_ENGINE}" != "docker" ]; then
            echo "[ERROR] Unsupported container engine specified: ${CONTAINER_ENGINE}"
            exit 1
        fi
    fi
}

#
# Validates arguments for 'registry service stop' action
#
validate_registry_service_stop_arguments() {
    if [ ! -z "${CONTAINER_ENGINE}" ]; then
        if [ "${CONTAINER_ENGINE}" != "podman" ] && [ "${CONTAINER_ENGINE}" != "docker" ]; then
            echo "[ERROR] Unsupported container engine specified: ${CONTAINER_ENGINE}"
            exit 1
        fi
    fi
}

#
# Validates required tools for 'registry service init'
#
validate_registry_service_init_required_tools() {
    # validate required tools - htpasswd
    htpasswd_command=$(command -v htpasswd 2> /dev/null)
    if [ -z "${htpasswd_command}" ];
    then
        echo "[ERROR] htpasswd not found. For RHEL, use 'sudo yum install httpd-tools' to install"
        exit 1
    fi

    # validate required tools - htpasswd
    openssl_command=$(command -v openssl 2> /dev/null)
    if [ -z "${openssl_command}" ];
    then
        echo "[ERROR] openssl not found. For RHEL, use 'sudo re' to install"
        exit 1
    fi
}

# ---------- Registry secret functions ----------

#
# Handles creating registry authentication secret
#
do_registry_secret_create() {
    # parses arguments
    parse_registry_secret_create_arguments "$@"

    # validates arguments
    validate_registry_secret_create_arguments

    # creates auth data path
    if [ ! -d "${AUTH_DATA_PATH}" ] || [ ! -d "${AUTH_DATA_PATH}/secrets" ]; then
        mkdir -p "${AUTH_DATA_PATH}/secrets"
    fi

    # creates docker auth secret
    echo "[INFO] Creating registry authencation secret for ${AUTH_REGISTRY_SERVER}"
    registry_secret_file=${AUTH_DATA_PATH}/secrets/${AUTH_REGISTRY_SERVER}.json
    registry_secret=$(echo -n "${AUTH_REGISTRY_USERNAME}:${AUTH_REGISTRY_PASSWORD}" | base64 | tr -d "\n")
    
    echo -n "{\"auths\":{\"${AUTH_REGISTRY_SERVER}\":{\"email\":\"${AUTH_REGISTRY_EMAIL}\",\"auth\":\"${registry_secret}\"}}}" > "${registry_secret_file}"
    chmod 600 "${registry_secret_file}"

    echo "[INFO] Registry secret created in ${registry_secret_file}"
    
    echo "[INFO] Done"
}

#
# Handles deleting registry authentication secret
#
do_registry_secret_delete() {
    # parses arguments
    parse_registry_secret_delete_arguments "$@"

    # validates arguments
    validate_registry_secret_delete_arguments

    # checks if auth secret exists
    if [ -f "${AUTH_DATA_PATH}/secrets/${AUTH_REGISTRY_SERVER}.json" ]; then
        echo "[INFO] Deleteing authentication secret for ${AUTH_REGISTRY_SERVER}"
        rm -f "${AUTH_DATA_PATH}/secrets/${AUTH_REGISTRY_SERVER}.json" 

        if [[ "$?" -eq 0 ]]; then
            echo "[INFO] Done"
        else
            exit 11
        fi
    else
        echo "[ERROR] Registry authentication for ${AUTH_REGISTRY_SERVER} not found"
        exit 1
    fi
}

#
# Handles listing registry authentication secrets
#
do_registry_secret_list() {
    secrets=
    if [ -d "${AUTH_DATA_PATH}/secrets" ]; then
        secrets=$(find "${AUTH_DATA_PATH}/secrets" -name "*.json")
    fi

    if [ ! -z "${secrets}" ]; then
        for secret in ${secrets}; do
            registry=$(echo "${secret}" | sed -e "s/.*\///" | sed -e "s/.json$//")
            echo "${registry}"
        done
    else
        echo "[INFO] No registry secret found"
    fi
}

#
# Handles deleting all registry authentication secrets
#
do_registry_secret_delete_all() {
    if [ -d "${AUTH_DATA_PATH}" ]; then
        echo "[INFO] Deleting registry authentications"
        rm -rf "${AUTH_DATA_PATH}"

        if [[ "$?" -eq 0 ]]; then
            echo "[INFO] Done"
        else
            exit 11
        fi
    else
        echo "[ERROR] Registry authentications not found"
        exit 1
    fi
}

#
# Parses arguments for 'registry secret' action
#
parse_registry_secret_arguments() {
    if [[ "$#" == 0 ]]; then
        print_registry_secret_usage
        exit 1
    fi
    
    # process options
    while [ "$1" != "" ]; do
        case "$1" in
        -c | --create)
            shift
            do_registry_secret_create "$@"
            break
            ;;
        -d | --delete)
            shift
            do_registry_secret_delete "$@"
            break
            ;;
        -l | --list)
            do_registry_secret_list
            break
            ;;
        -D | --delete-all)
            shift
            do_registry_secret_delete_all
            break
            ;;
        -h | --help)
            print_registry_secret_usage
            exit 1
            ;;
        *)
            print_registry_secret_usage
            exit 1
            ;;
        esac
        shift
    done
}

#
# Parses arguments for 'secret create' action
#
parse_registry_secret_create_arguments() {
    if [[ "$#" == 0 ]]; then
        print_registry_secret_create_usage
        exit 1
    fi

    # process options
    while [ "$1" != "" ]; do
        case "$1" in
        -u | --username)
            shift
            AUTH_REGISTRY_USERNAME="$1"
            ;;
        -p | --password)
            shift
            AUTH_REGISTRY_PASSWORD="$1"
            ;;
        -e | --email)
            shift
            AUTH_REGISTRY_EMAIL="$1"
            ;;            
        -h | --help)
            print_registry_secret_create_usage
            exit 1
            ;;
        --dry-run)
            shift
            ;;
        *)
            AUTH_REGISTRY_SERVER="$1"
            ;;
        esac
        shift
    done
}

#
# Parses arguments for 'registry-secret delete' action
#
parse_registry_secret_delete_arguments() {
    if [[ "$#" == 0 ]]; then
        print_registry_secret_delete_usage
        exit 1
    fi

    # process options
    while [ "$1" != "" ]; do
        case "$1" in         
        -h | --help)
            print_registry_secret_delete_usage
            exit 1
            ;;
        *)
            AUTH_REGISTRY_SERVER="$1"
            ;;
        esac
        shift
    done
}

#
# Prints usage menu for 'registry secret' action
#
print_registry_secret_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} registry secret [OPTION]..."
    echo ""
    echo "Manage the authentication secrets of all the registries used in image mirroring"
    echo ""
    echo "Options:"
    echo "  -c, --create       Create an authentication secret"
    echo "  -d, --delete       Delete an authentication secret"
    echo "  -l, --list         List all authentication secrets"
    echo "  -D, --delete-all   Delete all authentication secrets"
    echo "  -h, --help         Print usage information"
    echo ""
}

#
# Prints usage menu for 'registry secret --create' action
#
print_registry_secret_create_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} registry secret --create -u USERNAME -p PASSWORD [-e EMAIL] REGISTRY_SERVER"
    echo ""
    echo "Creates a registry authentication secret"
    echo ""
    echo "Options:"
    echo "   -u, --username string   Account username"
    echo "   -p, --password string   Account password"
    echo "   -e, --email string      Account email (optional)"
    echo "   -h, --help              Print usage information"
    echo ""
}

#
# Prints usage menu for 'registry secret --delete' action
#
print_registry_secret_delete_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} registry secret --delete REGISTRY_SERVER"
    echo ""
    echo "Delete a registry authentication secret"
    echo ""
    echo "Options:"
    echo "   -h, --help   Print usage information"
    echo ""
}

#
# Validates arguments for 'registry-secret create' action
#
validate_registry_secret_create_arguments() {
    if [ -z "${AUTH_REGISTRY_SERVER}" ]; then
        echo "[ERROR] Registry server not specified"
        exit 1
    fi

    if [ -z "${AUTH_REGISTRY_USERNAME}" ]; then
        echo "[ERROR] Account username not specified"
        exit 1
    fi

    if [ -z "${AUTH_REGISTRY_PASSWORD}" ]; then
        echo "[ERROR] Account password not specified"
        exit 1
    fi

    if [ -z "${AUTH_REGISTRY_EMAIL}" ]; then
        AUTH_REGISTRY_EMAIL="unused"
    fi
}

#
# Validates arguments for 'registry-secret delete' action
#
validate_registry_secret_delete_arguments() {
    if [ -z "${AUTH_REGISTRY_SERVER}" ]; then
        echo "[ERROR] Registry server not specified"
        exit 1
    fi
}

# ---------- Image mirror functions ----------

#
# Handles 'image mirror' action
#
do_image_mirror() {
    # parses arguments
    parse_image_mirror_arguments "$@"
    
    # validates arguments
    validate_image_mirror_arguments

    # verifies if target registry is SSL enabeld
    if [[ ! -z "$(curl -I -k https://${TARGET_REGISTRY} --connect-timeout 5 2>/dev/null | grep '200')" ]]; then
        REGISTRY_TLS_ENABLED=false
    fi

    if [[ "${SHOW_REGISTRIES}" == "true" || "${SHOW_REGISTRIES_NAMESPACES}" == "true" ]]; then
        do_image_mirror_show_registries
    else
        # generates auth.json for 'oc image mirror'
        #generate_auth_json

        # mirror images
        if [ ! -z "${IMAGE}" ]; then
            if [ ! -z "${USE_SKOPEO}" ]; then
                do_skopeo_copy_single_image
            else
                do_image_mirror_single_image
            fi
        elif [ ! -z "${IMAGE_CSV_FILE}" ]; then
            process_case_csv_file "${IMAGE_CSV_FILE}"
            generate_image_mapping_file
            if [ ! -z "${USE_SKOPEO}" ]; then
                do_skopeo_copy_case_images
            else
                do_image_mirror_case_images
            fi
            tag_latest_olm_catalog_images
        elif [ ! -z $CASE_ARCHIVE_DIR ]; then
            process_case_archive_dir
            generate_image_mapping_file
             if [ ! -z "${USE_SKOPEO}" ]; then
                do_skopeo_copy_case_images
            else
                do_image_mirror_case_images
            fi
            tag_latest_olm_catalog_images
        fi
    fi
}


#
# Uses `oc image mirror` command to mirror one ad-hoc image
#
do_image_mirror_single_image() {
    image_identifier=$(echo "${IMAGE}" | sed -e "s/[^/]*\///") # removes registry host
    image_identifier=$(echo "${image_identifier}" | sed -e "s/\@.*//") # removes image digest
    image_identifier=$(update_image_namespace "${image_identifier}") # updates namespace

    # replace the original registry with the specified source registry
    if [  ! -z "${SOURCE_REGISTRY}" ]; then
        IMAGE=$(echo "${IMAGE}" | sed -e "s/[^\/]*/${SOURCE_REGISTRY}/")
    fi

    echo "[INFO] Start mirroring image ..."
    oc_cmd="oc image mirror -a \"${AUTH_DATA_PATH}/auth.json\" \"${IMAGE}\" \"${TARGET_REGISTRY}/${image_identifier}\" --filter-by-os '.*' --insecure ${DRY_RUN}" 
    echo "${oc_cmd}"
    eval ${oc_cmd}

    if [[ "$?" -ne 0 ]]; then
        exit 11
    fi
}

#
# Uses `skopeo copy` command to mirror one ad-hoc image
#
do_skopeo_copy_single_image() {
    image_identifier=$(echo "${IMAGE}" | sed -e "s/[^/]*\///") # removes registry host
    image_identifier=$(echo "${image_identifier}" | sed -e "s/\@.*//") # removes image digest
    image_identifier=$(update_image_namespace "${image_identifier}") # updates namespace

    # replace the original registry with the specified source registry
    if [  ! -z "${SOURCE_REGISTRY}" ]; then
        IMAGE=$(echo "${IMAGE}" | sed -e "s/[^\/]*/${SOURCE_REGISTRY}/")
    fi
    
    echo "[INFO] Start copying image ..."
    oc_cmd="skopeo copy --all --authfile \"${AUTH_DATA_PATH}/auth.json\" --dest-tls-verify=false --src-tls-verify=false \"docker://${IMAGE}\" \"docker://${TARGET_REGISTRY}/${image_identifier}\""
    echo "${oc_cmd}"
    eval ${oc_cmd}

    if [[ "$?" -ne 0 ]]; then
        exit 11
    fi
}

#
# Uses `oc image mirror` command to mirror the CASE images
# 
do_image_mirror_case_images() {
    if [ ! -f "${OC_TMP_IMAGE_MAP}" ]; then
        echo "[ERROR] No image mapping found"
        exit 11
    fi

    # replace the original registry with the specified source registry
    if [  ! -z "${SOURCE_REGISTRY}" ]; then
        cat ${OC_TMP_IMAGE_MAP} | sed -e "s/[^\/]*/${SOURCE_REGISTRY}/" 1<> "${OC_TMP_IMAGE_MAP}"
    fi


    echo "[INFO] Start mirroring CASE images ..."
    
    images_count=$(wc -l "${OC_TMP_IMAGE_MAP}" | awk '{ print $1 }')
    map_files="${OC_TMP_IMAGE_MAP}"

    echo "[INFO] Found ${images_count} images"

    # Remove ppc64le and s390x images
    sed -i "/ppc64le/d" ${OC_TMP_IMAGE_MAP}
    sed -i "/x390x/d" ${OC_TMP_IMAGE_MAP}
    images_count=$(wc -l "${OC_TMP_IMAGE_MAP}" | awk '{ print $1 }')

    echo "[INFO] Found ${images_count} images after filtering"

    # cat ${OC_TMP_IMAGE_MAP} | grep "/ibmcom/" > ${OC_TMP_IMAGE_MAP}_ibmcom
    # sed -i "s/cp.icr.io/docker.io/" ${OC_TMP_IMAGE_MAP}_ibmcom
    # sed -i "/\/ibmcom\//d" ${OC_TMP_IMAGE_MAP}

    # images_count=$(wc -l "${OC_TMP_IMAGE_MAP}" | awk '{ print $1 }')

    # echo "[INFO] Found ${images_count} images after removing ibmcom"

    # cat ${OC_TMP_IMAGE_MAP} | grep "/opencloudio/" > ${OC_TMP_IMAGE_MAP}_opencloudio
    # sed -i "s/cp.icr.io/quay.io/" ${OC_TMP_IMAGE_MAP}_opencloudio
    # sed -i "/\/opencloudio\//d" ${OC_TMP_IMAGE_MAP}

    # images_count=$(wc -l "${OC_TMP_IMAGE_MAP}" | awk '{ print $1 }')

    # echo "[INFO] Found ${images_count} images after removing opencloudio"

    # Exit cleanly if no images are found to mirror
    if [[ ${images_count} == 0 ]]; then
      for mirrored_csv in ${MIRRORED_IMAGE_CSV_CONTEXT[@]}; do
        if [[ ${mirrored_csv} == *"-delta-images-"* ]]; then
          cleanup_mirrored_csv_files_from_current_run
          echo "[WARN] Found 0 images that had not already been mirrored. No additional work to do. Use the --skip-delta argument to force images to be mirrored."
          exit 11
        fi
      done
      cleanup_mirrored_csv_files_from_current_run
      echo "[WARN] Found 0 images to be mirrored. Make sure that the download directory path is correct and that any specified groups are valid."
      exit 11
    fi

    if [[ "${OC_TMP_IMAGE_MAP_SPLIT_SIZE}" -gt 0 ]] && [[ ${images_count} -gt ${OC_TMP_IMAGE_MAP_SPLIT_SIZE} ]]; then
        # splitting the image map into multiple files
        mkdir -p "${OC_TMP_IMAGE_MAP}_splits"
        split -l ${OC_TMP_IMAGE_MAP_SPLIT_SIZE} ${OC_TMP_IMAGE_MAP} ${OC_TMP_IMAGE_MAP}_splits/image_map_
        map_files=$(find "${OC_TMP_IMAGE_MAP}_splits" -name "image_map_*")
    fi

    for map_file in ${map_files}; do
        echo "[INFO] Mirroring ${map_file}"
        oc_cmd="time oc image mirror -a \"${XDG_RUNTIME_DIR}/containers/auth.json\" -f \"${map_file}\" --filter-by-os '.*' --insecure ${DRY_RUN}"
        echo "${oc_cmd}"
        eval ${oc_cmd}

        if [[ "$?" -ne 0 ]]; then
            # On error we need to clean up our mirrored csv file
            cleanup_mirrored_csv_files_from_current_run
            
            exit 11
        fi
    done

    # oc_cmd="time oc image mirror -a \"${XDG_RUNTIME_DIR}/containers/auth.json\" -f \"${OC_TMP_IMAGE_MAP}_ibmcom\" --filter-by-os '.*' --insecure ${DRY_RUN}"
    # echo "${oc_cmd}"
    # eval ${oc_cmd}

    # oc_cmd="time oc image mirror -a \"${XDG_RUNTIME_DIR}/containers/auth.json\" -f \"${OC_TMP_IMAGE_MAP}_opencloudio\" --filter-by-os '.*' --insecure ${DRY_RUN}"
    # echo "${oc_cmd}"
    # eval ${oc_cmd}


}

#
# Uses `skopeo copy` command to mirror the CASE images
#
do_skopeo_copy_case_images() {
    if [ ! -f "${OC_TMP_IMAGE_MAP}" ]; then
        echo "[ERROR] No image mapping found"
        exit 11
    fi

    # replace the original registry with the specified source registry
    if [  ! -z "${SOURCE_REGISTRY}" ]; then
        cat ${OC_TMP_IMAGE_MAP} | sed -e "s/[^\/]*/${SOURCE_REGISTRY}/" 1<> "${OC_TMP_IMAGE_MAP}"
    fi
    # change delimiter from '= to space and add transport
    cat ${OC_TMP_IMAGE_MAP} | sed -e "s/=/ docker:\/\//" 1<> "${OC_TMP_IMAGE_MAP}"

    echo "[INFO] Start mirroring CASE images ..."

    while read in; do
        oc_cmd="skopeo copy --all --authfile \"${AUTH_DATA_PATH}/auth.json\" --dest-tls-verify=false --src-tls-verify=false docker://${in}" ;
        echo "${oc_cmd}"
        eval ${oc_cmd}

        if [[ "$?" -ne 0 ]]; then
            # On error we need to clean up our mirrored csv file
            cleanup_mirrored_csv_files_from_current_run

            exit 11
        fi
    done < ${OC_TMP_IMAGE_MAP}
}

#
# Shows all the registries that would be used
#
do_image_mirror_show_registries() {
    # generates image mapping file
    if [ ! -z "${IMAGE}" ]; then
        process_single_image_mapping
    elif [ ! -z "${IMAGE_CSV_FILE}" ]; then
        process_case_csv_file "${IMAGE_CSV_FILE}"
        generate_image_mapping_file
    elif [ ! -z $CASE_ARCHIVE_DIR ]; then
        process_case_archive_dir
        generate_image_mapping_file
    fi

    if [ -f "${OC_TMP_IMAGE_MAP}" ]; then
        # replace the original registry with the specified source registry
        if [  ! -z "${SOURCE_REGISTRY}" ]; then
            cat ${OC_TMP_IMAGE_MAP} | sed -e "s/[^\/]*/${SOURCE_REGISTRY}/" 1<> ${OC_TMP_IMAGE_MAP}
        fi

        if [[ "${SHOW_REGISTRIES}" == "true" ]]; then
            echo "[INFO] Registries that would be used in this action"
            cat "${OC_TMP_IMAGE_MAP}" | awk -F'/' '{ print $1 }' | sort -u

            if [ ! -z "${TARGET_REGISTRY}" ]; then
                echo "${TARGET_REGISTRY}"
            fi
        elif [[ "${SHOW_REGISTRIES_NAMESPACES}" == "true" ]]; then
            echo "[INFO] Registries and namespaces that would be used in this action"
            cat "${OC_TMP_IMAGE_MAP}" | awk -F'/' '{ print $1 "/" $2 }' | sort -u
        fi
    else
        echo "[ERROR] No registry found"
    fi
}

#
# Validates that the OLM catalog image tag must be in the following formats:
# vX.Y[.Z]-YYYYMMDD.HHmmss[-HEXCOMMIT][-OS.ARCH[.VAR]]]
# [v]X.Y[.Z]
# YYYY-MM-DD-HHmmss[-HEXCOMMIT]
#
is_valid_olm_catalog_tag() {
    local tag=$1

    if [[ ${tag} =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?-[0-9]{8}\.[0-9]{6}(-[A-Fa-f0-9]{9})?-(linux|windows)\.(amd64|arm32|arm64|i386|mips64le|ppc64le|s390x|windows-amd64)(.v[5-8])?$ ]]; then
        # OFFICIAL tag with os-arch formats:
        # v4.5.1-20200902.220310-CE62727AE-linux.arm64.v8 or v4.5-20200902.220310-CE62727AE-linux.arm64.v8
        # v4.5.1-20200902.220310-CE62727AE-linux.amd64 or v4.5-20200902.220310-CE62727AE-linux.amd64
        # v4.5.1-20200902.220310-linux.arm64.v8 or v4.5-20200902.220310-linux.arm64.v8
        # v4.5.1-20200902.220310-linux.amd64 or v4.5-20200902.220310-linux.amd64
        echo "true"
    elif [[ ${tag} =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?-[0-9]{8}\.[0-9]{6}(-[A-Fa-f0-9]{9})?$ ]]; then
        # OFFICIAL tag without os-arch formats:
        # v4.5.1-20200902.220310-CE62727AE or v4.5-20200902.220310-CE62727AE
        # v4.5.1-20200902.220310 or v4.5-20200902.220310
        echo "true"
    elif [[ ${tag} =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
        # SEMVER tag with exact match formats: 2.0 or 2.0.1
        echo "true"
    elif [[ ${tag} =~ ^[0-9]+(\.[0-9]+){1,2}-[A-Za-z0-9] ]]; then
        # SEMVER tag with leading match formats: 2.0-beta or 2.1.0-linux.amd64
        echo "true"
    elif [[ ${tag} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}(-[A-Fa-f0-9]{9})?$ ]]; then
        # TIMESTAMP tag with exact match formats: 2020-06-25-052612-e9a7f609f or 2020-06-25-052612
        echo "true"
    elif [[ ${tag} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}(-[A-Fa-f0-9]{9})?-[A-Za-z] ]]; then
        # TIMESTAMP tag with leading match formats: 2020-06-25-052612-e9a7f609f-beta or 2020-06-25-052612-linux.amd64
        echo "true"
    elif [[ ${tag} =~ ^v?[0-9]+$ ]]; then
        # INTEGER tag with exact match formats: v1 or 1
        echo "true"
    elif [[ ${tag} =~ ^v?[0-9]+-[A-Za-z] ]]; then
        # INTEGER tag with leading match formats: v1-beta or 1-linux.amd64
        echo "true"
    else
        # no match
        echo "false"
    fi
}

#
# Returns the significant portion of a supported tag
# 
get_tag_significance() {
    local tag=$1
    local significance=

    if [[ ${tag} =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?-[0-9]{8}\.[0-9]{6}$ || ${tag} =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?-[0-9]{8}\.[0-9]{6}- ]]; then
        # OFFICIAL tag with significant portion: v4.5.1-20200902
        significance=$(echo "${tag}" | sed -e 's|^\(v[0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?-[0-9]\{8\}\).*|\1|')
    elif [[ ${tag} =~ ^[0-9]+(\.[0-9]+){1,2}$ || ${tag} =~ ^[0-9]+(\.[0-9]+){1,2}-[A-Za-z] ]]; then
        # SEMVER tag significant portion: 1.2.3
        significance=$(echo "${tag}" | sed -e 's|^\([0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?\)-.*|\1|')
    elif [[ ${tag} =~ ^[0-9]+(\.[0-9]+){1,2}-[0-9]{4}-[0-9]{2}-[0-9]{2}- ]]; then
        # SEMVER tag with timestamp significant portion: 1.2.3-2020-06-25
        significance=$(echo "${tag}" | sed -e 's|^\([0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?-[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)-.*|\1|')
    elif [[ ${tag} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ || ${tag} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}$ || ${tag} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}-[A-Za-z0-9] ]]; then
        # TIMESTAMP tag significant portion: 2020-06-25
        significance=$(echo "${tag}" | sed -e 's|^\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)-.*|\1|')
    elif [[ ${tag} =~ ^v?[0-9]+$ || ${tag} =~ ^v?[0-9]+-[A-Za-z] ]]; then
        # INTEGER tag significant portion: v1 or 1
        significance=$(echo "${tag}" | sed -e 's|^\(v\?[0-9]\+\)-.*|\1|')
    fi

    echo $significance
}

#
# Tags latest OLM catalog images
#
tag_latest_olm_catalog_images() {
    if [[ ! -z "${DRY_RUN}" ]]; then
        # skip for dry-run
        return
    fi

    if [ -f "${OC_TMP_IMAGE_MAP}.CATALOG" ]; then
        catalog_images=$(cat "${OC_TMP_IMAGE_MAP}.CATALOG" | grep "=olm-catalog=")

        REGISTRY_TLS_ENABLED=false
        if [[ ! -z "${catalog_images}" ]] && [[ "${REGISTRY_TLS_ENABLED}" == "true" ]]; then
            extract_ca_cert
        fi

        for catalog_image in ${catalog_images}; do
            image=$(echo "${catalog_image}" | awk -F'=' '{ print $2 }' | rev | sed -e "s|[^:]*:||" | rev)
            tag=$(echo "${catalog_image}" | awk -F'=' '{ print $2 }' | sed -e "s|.*:||")
            sha=$(echo "${catalog_image}" | awk -F'=' '{ print $1 }' | sed -e "s|.*@||")
            arch=$(echo "${catalog_image}" | awk -F'=' '{ print $4 }')
            latest_tag="latest"

            # append arch to latest_tag
            if [[ ! -z "${arch}" ]]; then
                latest_tag="${latest_tag}-${arch}"
            fi

            # only considers tag with supported format
            if [[ "$(is_valid_olm_catalog_tag ${tag})" == "true" ]]; then
                validate_image_mirror_required_tools
                echo "[INFO] Retrieving image tags from ${image}"
                if [[ "${REGISTRY_TLS_ENABLED}" == "true" ]]; then
                    skopeo_cmd="skopeo list-tags --authfile ${AUTH_DATA_PATH}/auth.json --cert-dir ${AUTH_DATA_PATH}/certs docker://${image}"
                else
                    skopeo_cmd="skopeo list-tags --tls-verify=false --authfile ${AUTH_DATA_PATH}/auth.json docker://${image}"
                fi
                echo "[INFO] ${skopeo_cmd}"
                all_tags=$(${skopeo_cmd} | tr -d "\r|\n| " | sed -e 's|.*"Tags":\[||' | sed -e 's|\].*||' | sed -e 's|"||g' | sed -e 's|,|\n|g' | grep -v '^latest' | sort -V)
                printf "[INFO] Available tags:\n${all_tags}\n"

                if [[ ! -z "${all_tags}" ]]; then
                    last_tag=$(printf "${all_tags}" | tail -1)
                    tag_significane=$(get_tag_significance "${tag}")

                    if [[ ${last_tag} =~ ^${tag_significane} ]]; then
                        # tags the current image as latest if the latest tag already exists 
                        # and the current image is the most recent version
                        echo "[INFO] Tagging ${image}:${tag} as ${image}:${latest_tag}"    

                        oc_cmd="oc image mirror -a \"${AUTH_DATA_PATH}/auth.json\" \"${image}@${sha}\" \"${image}:${latest_tag}\" --filter-by-os '.*' --insecure ${DRY_RUN}"
                        echo "${oc_cmd}"
                        eval ${oc_cmd}

                        if [[ "$?" -ne 0 ]]; then
                            exit 11
                        fi
                    else
                        echo "[INFO] Not most recent tag ${tag}, skip tagging as ${latest_tag}"
                    fi
                fi
            fi
        done
    fi
}

#
# Generates auth.json file for 'oc image mirror'
#
generate_auth_json() {
    echo "[INFO] Generating auth.json"
    printf "{\n  \"auths\": {" > "${AUTH_DATA_PATH}/auth.json"
    chmod 600 "${AUTH_DATA_PATH}/auth.json"

    if [ -d "${AUTH_DATA_PATH}/secrets" ]; then
        all_registry_auths=
        for secret in $(find "${AUTH_DATA_PATH}/secrets" -name "*.json"); do
            registry_auth=$(cat ${secret} | sed -e "s/^{\"auths\":{//" | sed -e "s/}}$//")
            if [[ "$?" -eq 0 ]]; then
                if [ ! -z "${all_registry_auths}" ]; then
                    printf ",\n    ${registry_auth}" >> "${AUTH_DATA_PATH}/auth.json"
                else
                    printf "\n    ${registry_auth}" >> "${AUTH_DATA_PATH}/auth.json"
                fi
                all_registry_auths="${all_registry_auths},${registry_auth}"
            fi
        done
    fi

    printf "\n  }\n}\n" >> "${AUTH_DATA_PATH}/auth.json"
}

#
# Generates image mapping file
#
generate_image_mapping_file() {
    echo "[INFO] Generating image mapping file ${OC_TMP_IMAGE_MAP}"
    mtype=(IMAGE LIST)
    for type in "${mtype[@]}"; do
        if [ -f "${OC_TMP_IMAGE_MAP}.${type}" ]; then
            # sort and remove duplicates
            cat "${OC_TMP_IMAGE_MAP}.${type}" | sed -e "s|=olm-catalog=.*||g" | sort -u >> "${OC_TMP_IMAGE_MAP}"
            cat "${OC_TMP_IMAGE_MAP}.${type}" | grep -E "=olm-catalog=" | sort -u >> "${OC_TMP_IMAGE_MAP}.CATALOG"
        fi
    done
}

#
# Processes single image mapping
#
process_single_image_mapping() {
    image_identifier=$(echo "${IMAGE}" | sed -e "s/[^/]*\///") # removes registry host
    image_identifier=$(update_image_namespace "${image_identifier}") # updates registry host
    echo "${IMAGE}=${TARGET_REGISTRY}/${image_identifier}" > "${OC_TMP_IMAGE_MAP}"
}

#
# Cleanup the mirrored images CSV files from the current run when 
# oc image mirror command fails
#
cleanup_mirrored_csv_files_from_current_run() {
    echo "[INFO] Deleting mirrored image csv files created during this mirror attempt"
    for mirrored_csv in ${MIRRORED_IMAGE_CSV_CONTEXT[@]}; do
        rm -f ${mirrored_csv}
    done
}

#
# Create a mirrored image CSV file for the local disk
# File is saved in a folder in the offline cache that
# matches the name of the registry mirrored to 
#
create_mirrored_images_csv() {
    # Since we are not actually mirroring any images,
    # do not create a csv file that claims we did
    if [[ ! -z ${DRY_RUN} ]]; then 
        echo "[INFO] Dry run is set, skipping mirrored images csv generation"
    else 
        local image_csv="${1}"
        local registry="${2}"
        local time_stamp="${3}"

        # Remove the :port from the input registry
        formated_registry="$(echo ${registry} | cut -d ':' -f 1)"
        local registry_dir="${OC_TMP_CASE_DIR}/${formated_registry}"

        if [ ! -d ${registry_dir} ]; then 
            mkdir -p "${registry_dir}"
        fi

        # Get just the case name and version from the image CSV file
        local image_basename="$(basename ${image_csv})"
        local mirrored_csv_name="$(echo ${image_basename} | sed -e 's|-images.csv.tmp||g')"
        if [ ${image_basename} == ${mirrored_csv_name} ]; then
        mirrored_csv_name="$(echo ${image_basename} | sed -e 's|.csv.tmp||g')"
        fi
        local mirrored_csv_file_path="${registry_dir}/${mirrored_csv_name}-mirrored-images.csv"

        # If a file of this name already exists in the directory, then add some timestamp information to it
        if [ -f ${mirrored_csv_file_path} ]; then 
            echo "[INFO] Updating a CSV file of mirrored images at ${mirrored_csv_file_path}"

            # mirrored_csv_file_path="${registry_dir}/${mirrored_csv_name}-${time_stamp}-mirrored-images.csv"
            local lines="$(cat ${image_csv})"
            for line in ${lines[@]}; do
                rc=0
                grep "${mirrored_csv_file_path}" -e "${line}" 2> /dev/null; rc=${?}
                # Append non-unique and already existing lines to the csv file
                if [[ ${rc} -eq 1 ]]; then 
                    echo "${line}" >> "${mirrored_csv_file_path}"
                fi
            done
        else
            echo "[INFO] Creating a CSV file of mirrored images at ${mirrored_csv_file_path}"

            cp "${image_csv}" "${mirrored_csv_file_path}"
        fi

        # Add the mirrored CSV path to the global context to be used later
        MIRRORED_IMAGE_CSV_CONTEXT[${#MIRRORED_IMAGE_CSV_CONTEXT[@]}]="${mirrored_csv_file_path}"
    fi
}

#
# Processes a CASE CSV file and output to ${OC_TMP_IMAGE_MAP} file
#
process_case_csv_file() {
    csv_file="${1}"

    # Begin filtering the images based on input groups
    local readonly base_csv="$(basename ${csv_file})"
    local tmp_csv_file="${OC_TMP_CSV_DIR}/${base_csv}"
    if [ ! -d $(dirname ${tmp_csv_file}) ]; then mkdir -p $(dirname ${tmp_csv_file}); fi
    if [ -f "${tmp_csv_file}" ]; then rm -f "${tmp_csv_file}"; fi
    
    echo "[INFO] Copying image CSV file at ${csv_file} to ${tmp_csv_file} temporarily"

    # Defaulting behavior to mirror everything
    if [[ -z ${IMAGE_GROUPS} ]]; then
        cp "${csv_file}" "${tmp_csv_file}"
    else 
        # New behavior to filter images from the CSV file
        old_ifs=${IFS}
        IFS=","
        local image_groups_arr=($IMAGE_GROUPS)
        IFS=${old_ifs}

        head -n 1 ${csv_file} > ${tmp_csv_file}
        local image_csv_lines=($(cat ${csv_file}))
        for i in "${!image_csv_lines[@]}"; do
            if [ ${i} -eq 0 ]; then continue; fi 
            # 12 is the column order number for the groups field in the CSV
            local line_groups=$(printf ${image_csv_lines[${i}]} | awk -F ',' '{ print $12 }')
            line_groups=$(echo ${line_groups} | sed -e "s|[\"']||g")
            #
            # If there are no groups in the row, or group columns in the CSV,
            # then default to add the row to the temp CSV file
            #
            if [[ -z ${line_groups} ]]; then
                echo "${image_csv_lines[${i}]}" >> "${tmp_csv_file}"
            else 
                old_ifs=${IFS}
                IFS=";"
                local line_groups_arr=($line_groups)
                IFS=${old_ifs}
                # Check for existence of the passed in resource groups in the csv row item
                for i_group in ${image_groups_arr[@]}; do
                    if [[ " ${line_groups_arr[@]} " =~ " ${i_group} " ]]; then
                        echo "${image_csv_lines[${i}]}" >> "${tmp_csv_file}"
                        break
                    fi
                done
            fi 
        done
    fi

    # End filtering the images based on input groups

    default_tag=$(date "+%Y%m%d%M%S")

    # Since the tmp_csv_file feeds the generation of the oc image mirror mapping
    # then use this as the file to save as the content that was mirrored in this run
    #
    # Only create the mirrored images csv file when the mirror action is called
    if [[ ! -z ${IMAGE_MIRROR_ACTION_CALLED} ]]; then 
        create_mirrored_images_csv "${tmp_csv_file}" "${TARGET_REGISTRY}" "${default_tag}"
    fi

    echo "[INFO] Processing image CSV file at ${tmp_csv_file}"
    
    # process FAT and LIST images, and print $registry/$image_name:$digest=$target_registry/$image_name:$tag
    mtype=(IMAGE LIST)
    for type in "${mtype[@]}"; do
        cat "${tmp_csv_file}" | sed -e "s|[\"']||g" | grep ",${type}," \
        | awk -v target_registry=${TARGET_REGISTRY} -v default_tag=${default_tag} \
            -v ns_action=${NAMESPACE_ACTION} -v ns_value=${NAMESPACE_ACTION_VALUE} -F',' \
        '{ printf $1 "/" $2 "@" $4 "=" target_registry "/" } \
        { split($2, paths, "/"); sub(paths[1], "", $2);
          if (ns_action == "replace") { printf ns_value } \
          else if (ns_action == "prefix") { printf ns_value paths[1] } \
          else if (ns_action == "suffix") { printf paths[1] ns_value } \
          else { printf paths[1] } \
          printf $2
        } \
        { printf ":" ($3 == "" ? default_tag ( $6 != "" ? "-" $6 : "") ( $7 != "" ? "-" $7 : "") : $3) \
        } \
        { print ($11 == "olm-catalog" ? ( "=" $11 "=" $7 ) : "") }' \
        >> "${OC_TMP_IMAGE_MAP}.${type}"
    done

    echo "[INFO] removing temp ${tmp_csv_file} images.csv file"
    rm -f "${tmp_csv_file}"
}

#
# Process all the CASE images CSV files found in the CASE archive directory
#
process_case_archive_dir() {
    echo "[INFO] Processing CASE archive directory: ${CASE_ARCHIVE_DIR}"

    # If there is a delta CSV file and SKIP_DELTA is not set, then use the latest delta CSV in the registries dir
    delta_csv=
    # Remove the :port from the input registry
    formated_registry="$(echo ${TARGET_REGISTRY} | cut -d ':' -f 1)"
    local registry_dir="${OC}/${formated_registry}"

    # If the registry directory already exists, SKIP_DELTA is not set, and there is a CASE archive specified, then create the image delta
    if [ -z ${SKIP_DELTA} ]; then
      if [ -d ${registry_dir} ] && [ ! -z ${CASE_ARCHIVE} ]; then
        echo "[INFO] Attempting to create delta list of images"
        cloudctl case create-images-delta --case ${CASE_ARCHIVE_DIR}/${CASE_ARCHIVE} --registry ${formated_registry} > /dev/null 2>&1
        if [ $? == 0 ]; then
          echo "[INFO] Create delta images list successful"
        else
          echo "[INFO] Create delta images list unsuccessful. Full list of images will be mirrored."
        fi
      fi

      # Find the newest delta images file, if there is one
      my_array=($(ls ${registry_dir}/*-delta-images-*.csv 2> /dev/null | grep -v \\-mirrored-images.csv | awk '{ split($0,a,/-delta-images-/); print a[2] }' | sort -r))

      if [ ${#my_array[@]} -ne 0 ]; then
        delta_csv=`ls ${registry_dir}/*${my_array[0]}`
      fi
    fi

    # If we did not find a delta images CSV, then process all existing CSVs, otherwise only process the delta CSV
    if [ -z ${delta_csv} ]; then
      for csv_file in $(find ${CASE_ARCHIVE_DIR} -name '*-images.csv'); do
        # Exclude -mirrored csv files from the list to mirror
        if [[ ! "${csv_file}" == *"-mirrored-images.csv"* ]]; then 
          process_case_csv_file "${csv_file}"
        fi
      done
    else
      csv_base="$(basename ${delta_csv})"
      cp ${registry_dir}/$csv_base ${CASE_ARCHIVE_DIR}
      process_case_csv_file "${CASE_ARCHIVE_DIR}/${csv_base}"
      rm ${CASE_ARCHIVE_DIR}/${csv_base}
    fi
}

#
# Prints usage menu for 'image mirror' action
#
print_image_mirror_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} image mirror [--dry-run|--show-registries]"
    echo "       [--image IMAGE|--csv IMAGE_CSV_FILE|--dir CASE_ARCHIVE_DIR]"
    echo "       [--ns-replace NAMESPACE|--ns-prefix PREFIX|--ns-suffix SUFFIX]"
    echo "       [--from-registry SOURCE_REGISTRY] --to-registry TARGET_REGISTRY"
    echo ""
    echo "Mirror CASE images to an image registry to prepare for Air-Gapped installation"
    echo ""   
    echo "Options:"
    echo "   --image string                 Image to mirror"
    echo "   --csv string                   CASE images CSV file"
    echo "   --dir string                   CASE archive directory that contains the image CSV files"
    echo "   --ns-replace string            Replace the namespace of the mirror image"
    echo "   --ns-prefix string             Append a prefix to the namespace of the mirror image"
    echo "   --ns-suffix string             Append a suffix to the namespace of the mirror image"
    echo "   --from-registry string         Mirror the images from a private registry"
    echo "   --to-registry string           Mirror the images to another private registry"
    echo "   --split-size int               Mirror the images in batches with a given split size. Default is 100"
    echo "   --show-registries              Print the registries that would be used"
    echo "   --show-registries-namespaces   Print the registries and namespaces that would be used"
    echo "   --dry-run                      Print the actions that would be taken"   
    echo "   -h, --help                     Print usage information"
    echo ""
    echo "Example 1: Mirror all CASE images to a private registry"
    echo "${script_name} image mirror --dry-run --dir ./offline --to-registry registry1.example.com:5000"
    echo ""
    echo "Example 2: Mirror all CASE images from a private registry to a another private registry"
    echo "${script_name} image mirror --dry-run --dir ./offline --from-registry registry1.example.com:5000 --to-registry registry2.example.com:5000"   
    echo "" 
    exit 1
}

#
# Parses the CLI arguments for 'mirror' action
#
parse_image_arguments() {

    if [[ "$#" == 0 ]]; then
        print_image_mirror_usage
        exit 1
    fi
    
    # process options
    while [ "$1" != "" ]; do
        case "$1" in
        mirror)
            shift
            IMAGE_MIRROR_ACTION_CALLED="true"
            do_image_mirror "$@"
            break
            ;;
        -h | --help)
            print_image_mirror_usage
            exit 1
            ;;
        *)
            print_image_mirror_usage
            exit 1
            ;;
        esac
        shift
    done
}

#
# Parses the CLI arguments for 'mirror' action
#
parse_image_mirror_arguments() {
    if [[ "$#" == 0 ]]; then
        print_image_mirror_usage
        exit 1
    fi

    # process options
    while [ "$1" != "" ]; do
        case "$1" in
        --image)
            shift
            IMAGE="$1"
            ;;
        --csv)
            shift
            IMAGE_CSV_FILE="$1"
            ;;
        --dir)
            shift
            CASE_ARCHIVE_DIR="$1"
            ;;
        --archive)
            shift
            CASE_ARCHIVE="$1"
            ;;
        --ns-replace)
            shift
            NAMESPACE_ACTION="replace"
            NAMESPACE_ACTION_VALUE="$1"
            ;;
        --ns-prefix)
            shift
            NAMESPACE_ACTION="prefix"
            NAMESPACE_ACTION_VALUE="$1"
            ;;
        --ns-suffix)
            shift
            NAMESPACE_ACTION="suffix"
            NAMESPACE_ACTION_VALUE="$1"
            ;;
        --from-registry)
            shift
            SOURCE_REGISTRY="$1"
            ;;
        --to-registry)
            shift
            TARGET_REGISTRY="$1"
            ;;
        --split-size)
            shift
            OC_TMP_IMAGE_MAP_SPLIT_SIZE=$1
            ;;
        --show-registries)
            SHOW_REGISTRIES=true
            ;;
        --show-registries-namespaces)
            SHOW_REGISTRIES_NAMESPACES=true
            ;;
        --dry-run)
            DRY_RUN="--dry-run"
            ;;
        --groups)
            shift
            IMAGE_GROUPS="$1"
            ;;
        --skip-delta)
            shift
            SKIP_DELTA="$1"
            ;;
        -h | --help)
            print_image_mirror_usage
            exit 1
            ;;
        *)
            print_image_mirror_usage
            exit 1
            ;;
        esac
        shift
    done
}

#
# Validates the CLI arguments for 'mirror' action
#
validate_image_mirror_arguments() {
    if [[ -z "${TARGET_REGISTRY}" && -z "${SHOW_REGISTRIES_NAMESPACES}" ]]; then
        echo "[ERROR] The target registry was not specified"
        exit 1
    fi

    if [ -z "${IMAGE}" ] && [ -z "${IMAGE_CSV_FILE}" ] && [ -z "${CASE_ARCHIVE_DIR}" ]; then
        echo "[ERROR] One of --image or --csv or --case-dir parameter must be specified"
        exit 1
    fi

    if [ ! -z "${IMAGE_CSV_FILE}" ] && [  ! -z "${CASE_ARCHIVE_DIR}" ]; then
        echo "[ERROR] Only --csv or --case-dir parameter should be specified"
        exit 1
    fi

    if [ ! -z "${IMAGE_CSV_FILE}" ] && [ ! -f "${IMAGE_CSV_FILE}" ]; then
        echo "[ERROR] Invalid image CSV file: ${IMAGE_CSV_FILE}"
        exit 1
    fi

    if [ ! -z "${CASE_ARCHIVE_DIR}" ] && [ ! -d "${CASE_ARCHIVE_DIR}" ]; then
        echo "[ERROR] Invalid CASE archive directory: ${CASE_ARCHIVE_DIR}"
        exit 1
    fi

    if [ ! -z "${CASE_ARCHIVE}" ] && [[ ( ${CASE_ARCHIVE} != *.tgz ) ]]; then
        echo "[ERROR] Invalid CASE archive: ${CASE_ARCHIVE}"
        exit 1
    fi

    if [ ! -z "${NAMESPACE_ACTION}" ] && [ -z "${NAMESPACE_ACTION_VALUE}" ]; then
        echo "[ERROR] Missing an argument for namespace ${NAMESPACE_ACTION}"
        exit 1
    fi

    if [ ! -z "${SHOW_REGISTRIES}" ] && [  ! -z "${SHOW_REGISTRIES_NAMESPACES}" ]; then
        echo "[ERROR] Only one of --show-registries or --show-registries-namespaces parameter may be specified"
        exit 1
    fi

    split_size=$(echo "${OC_TMP_IMAGE_MAP_SPLIT_SIZE}" | grep -E "^\-?[0-9]?\.?[0-9]+$")
    if [ -z "${split_size}" ] || [[ ${OC_TMP_IMAGE_MAP_SPLIT_SIZE} -lt 0 ]]; then
        echo "[ERROR] Invalid split size"
        exit 1
    fi
}

#
# Validate required tools for image mirroring
#
validate_image_mirror_required_tools() {
    if [ -f "${OC_TMP_IMAGE_MAP}.CATALOG" ]; then
        catalog_images=$(cat "${OC_TMP_IMAGE_MAP}.CATALOG" | grep "=olm-catalog=")

        if [[ ! -z "${catalog_images}" ]]; then
            # validate required tools - skopeo
            skopeo_command=$(command -v skopeo 2> /dev/null)
            if [ -z "${skopeo_command}" ];
            then
                echo "[ERROR] skopeo not found. For RHEL, use 'sudo yum install skopeo' to install"
                exit 1
            fi
        fi
    fi
}

#
# Updates image namespace
#
update_image_namespace() {
    image="$1"
    if [ ! -z "${NAMESPACE_ACTION_VALUE}" ]; then
        if [ "${NAMESPACE_ACTION}" == "replace" ]; then
            image=$(echo "${image}" | sed -E "s/([^\/]*)\//${NAMESPACE_ACTION_VALUE}\//")
        elif [ "${NAMESPACE_ACTION}" == "prefix" ]; then
            image=$(echo "${image}" | sed -E "s/([^\/]*)\//${NAMESPACE_ACTION_VALUE}\1\//")
        elif [ "${NAMESPACE_ACTION}" == "suffix" ]; then
            image=$(echo "${image}" | sed -E "s/([^\/]*)\//\1${NAMESPACE_ACTION_VALUE}\//")
        fi
    fi
    echo "${image}"
}

# ---------- Configure cluster functions ----------

#
# Handles 'cluster' action
#
do_cluster() {
    parse_cluster_arguments "$@"
}

#
# Applies image content source policy
#
do_cluster_apply_image_policy() {
    # parses arguments
    parse_cluster_apply_image_policy_arguments "$@"
    
    # validates arguments
    validate_cluster_apply_image_policy_arguments
    
    # generates image mapping file
    if [ ! -z "${IMAGE}" ]; then
        process_single_image_mapping
    elif [ ! -z "${IMAGE_CSV_FILE}" ]; then
        process_case_csv_file "${IMAGE_CSV_FILE}"
        generate_image_mapping_file
    elif [ ! -z $CASE_ARCHIVE_DIR ]; then
        process_case_archive_dir
        generate_image_mapping_file
    fi

    # generates content source image policy yaml
    if [ -f "${OC_TMP_IMAGE_MAP}" ]; then
        printf "apiVersion: operator.openshift.io/v1alpha1\n" > "${OC_TMP_IMAGE_POLICY}"
        printf "kind: ImageContentSourcePolicy\n" >> "${OC_TMP_IMAGE_POLICY}"
        printf "metadata:\n" >> "${OC_TMP_IMAGE_POLICY}"
        printf "  name: ${IMAGE_POLICY_NAME}\n" >> "${OC_TMP_IMAGE_POLICY}"
        printf "spec:\n" >> "${OC_TMP_IMAGE_POLICY}"
        printf "  repositoryDigestMirrors:\n" >> "${OC_TMP_IMAGE_POLICY}"

        # generates reduced image mapping file without image name
        for line in $(cat ${OC_TMP_IMAGE_MAP}); do
            source_image=$(echo "${line}" | cut -d '=' -f1 | rev | sed -e "s|^[^/]*/||" | rev)
            mirror_image=$(echo "${line}" | cut -d '=' -f2 | rev | sed -e "s|^[^/]*/||" | rev)
            printf "${source_image}=${mirror_image}\n" >> "${OC_TMP_IMAGE_MAP}_reduced"
        done

        # generates content source image mapping rules
        for line in $(cat "${OC_TMP_IMAGE_MAP}_reduced" | sort -u); do
            source_image=$(echo "${line}" | cut -d '=' -f1)
            mirror_image=$(echo "${line}" | cut -d '=' -f2)
            printf "  - mirrors:\n" >> "${OC_TMP_IMAGE_POLICY}"
            printf "    - ${mirror_image}\n" >> "${OC_TMP_IMAGE_POLICY}"
            printf "    source: ${source_image}\n" >> "${OC_TMP_IMAGE_POLICY}"
        done

        # print the policy
        echo "[INFO] Generating image content source policy"
        echo "---"
        cat "${OC_TMP_IMAGE_POLICY}"
        echo "---"

        # apply oc command
        echo "[INFO] Applying image content source policy"
        oc_cmd="oc apply ${DRY_RUN} -f \"${OC_TMP_IMAGE_POLICY}\"" 
        echo "${oc_cmd}"
        eval ${oc_cmd}

        if [[ "$?" -ne 0 ]]; then
            exit 11
        fi
    else
        echo "[ERROR] No image mapping found"
        exit 1
    fi
}

#
# Updates cluster global pull secret
#
do_cluster_update_pull_secret() {
    # parses arguments
    parse_cluster_update_pull_secret_arguments "$@"
    
    # validates arguments
    validate_cluster_update_pull_secret_arguments

    # get existing cluster pull secret
    echo "[INFO] Retrieving cluster pull secret"
    current_pull_secret=$(oc -n openshift-config get secret/pull-secret -o jsonpath='{.data.\.dockerconfigjson}' | base64 --decode | tr -d "\r|\n| ")

    echo "[INFO] Retrieving target registry authentication secret"
    registry_secret_file="${AUTH_DATA_PATH}/secrets/${TARGET_REGISTRY}.json"
    registry_pull_secret=$(cat "${registry_secret_file}" | tr -d "\r|\n| " | sed -e "s/^{\"auths\":{//" | sed -e "s/}}$//")

    echo "[INFO] Merging cluster pull secret"
    if [[ "${current_pull_secret}" =~ "\"${TARGET_REGISTRY}\":" ]]; then
        echo "[INFO] No change"
    else
        new_pull_secret=$(echo "${current_pull_secret}" | sed -e "s/}}$//")
        new_pull_secret=$(echo "${new_pull_secret},${registry_pull_secret}}}")
        echo "${new_pull_secret}" > "${OC_TMP_PULL_SECRET}"

        # apply oc command
        echo "[INFO] Applying image content source policy"
        oc_cmd="oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=${OC_TMP_PULL_SECRET} ${DRY_RUN}" 
        echo "${oc_cmd}"
        eval ${oc_cmd}

        if [[ "$?" -ne 0 ]]; then
            exit 11
        fi
    fi
}

#
# Adds registry certificate authority to cluster
#
do_cluster_add_ca_cert() {
    # parses arguments
    parse_cluster_add_ca_cert_arguments "$@"
    
    # validates arguments
    validate_cluster_add_ca_cert_arguments

    # extracts ca certificate
    extract_ca_cert

    # checks for registries CAs configmap
    ca_configmap=$(oc -n openshift-config get configmap | grep "${REGISTRY_CA_CONFIGMAP}")

    # creates or updates registry ca configmap
    if [ -z "${ca_configmap}" ]; then
        echo "[INFO] Creating configmap ${REGISTRY_CA_CONFIGMAP}"
        oc_cmd="oc -n openshift-config create configmap ${REGISTRY_CA_CONFIGMAP} --from-file=${registry_key}=${AUTH_DATA_PATH}/certs/${TARGET_REGISTRY}-ca.crt ${DRY_RUN}"
        echo "${oc_cmd}"
        eval ${oc_cmd}

        if [[ "$?" -ne 0 ]]; then
            exit 11
        fi
    else
        echo "[INFO] Updating configmap ${REGISTRY_CA_CONFIGMAP}"
        
        oc -n openshift-config create configmap "${REGISTRY_CA_CONFIGMAP}" --from-file="${registry_key}=${AUTH_DATA_PATH}/certs/${TARGET_REGISTRY}-ca.crt" \
          --dry-run -o yaml > "${AUTH_DATA_PATH}/certs/${TARGET_REGISTRY}.yaml"

        oc -n openshift-config patch configmap "${REGISTRY_CA_CONFIGMAP}" -p "$(cat ${AUTH_DATA_PATH}/certs/${TARGET_REGISTRY}.yaml)" ${DRY_RUN}

        if [[ "$?" -ne 0 ]]; then
            rm "${AUTH_DATA_PATH}/certs/${TARGET_REGISTRY}.yaml"
            exit 11
        else
            rm "${AUTH_DATA_PATH}/certs/${TARGET_REGISTRY}.yaml"
        fi
    fi

    echo "[INFO] Updating cluster image configuration"
    oc patch image.config.openshift.io/cluster --patch "{\"spec\":{\"additionalTrustedCA\":{\"name\":\"${REGISTRY_CA_CONFIGMAP}\"}}}" --type=merge ${DRY_RUN}

    if [[ "$?" -ne 0 ]]; then
        exit 11
    fi
}

#
# Deletes registry certificate authority to cluster
#
do_cluster_delete_ca_cert() {
    # parses arguments
    parse_cluster_delete_ca_cert_arguments "$@"
    
    # validates arguments
    validate_cluster_delete_ca_cert_arguments

    # computes registry key
    registry_key=$(echo "${TARGET_REGISTRY}" | sed -e "s|:|..|")

    echo "[INFO] Deleting certificate authority for registry ${TARGET_REGISTRY}"
    oc -n openshift-config patch configmap "${REGISTRY_CA_CONFIGMAP}" \
      --type=json -p="[{\"op\": \"remove\", \"path\": \"/data/${registry_key}\"}]" ${DRY_RUN}

    if [[ "$?" -ne 0 ]]; then
        exit 11
    fi
}

#
# Extracts CA certificate from a server
#
extract_ca_cert() {
    # creates auth data path
    if [ ! -d "${AUTH_DATA_PATH}" ] || [ ! -d "${AUTH_DATA_PATH}/certs" ]; then
        mkdir -p "${AUTH_DATA_PATH}/certs"
    fi

    # computes registry key
    registry_key=$(echo "${TARGET_REGISTRY}" | sed -e "s|:|..|")

    # checks for default registry port
    if [[ ! "${TARGET_REGISTRY}" =~ .*":".* ]]; then
        TARGET_REGISTRY="${TARGET_REGISTRY}:443"
    fi

    # extracts ca from the registry server
    echo "[INFO] Extracting certificate authority from ${TARGET_REGISTRY} ..."
    openssl s_client -connect ${TARGET_REGISTRY} -showcerts 2>/dev/null </dev/null \
      | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p;' | cat -n | sort -nr | cut -f2  \
      | sed -ne '1,/-BEGIN CERTIFICATE-/p' | cat -n | sort -nr | cut -f2  > "${AUTH_DATA_PATH}/certs/${TARGET_REGISTRY}-ca.crt"

    # checks for return code
    if [ -s "${AUTH_DATA_PATH}/certs/${TARGET_REGISTRY}-ca.crt" ]; then
        echo "[INFO] Certificate authority saved to ${AUTH_DATA_PATH}/certs/${TARGET_REGISTRY}-ca.crt"
    else
        rm "${AUTH_DATA_PATH}/certs/${TARGET_REGISTRY}-ca.crt"
        echo "[ERROR] Unable to retrieve certificates from ${TARGET_REGISTRY}"
        exit 11
    fi
}

#
# Prints usage menu for 'cluster' action
#
print_cluster_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} cluster [apply-image-policy|update-pull-secret|add-ca-cert|delete-ca-cert]"
    echo ""
    echo "Configure an OpenShift cluster to use with a private registry"
    echo ""
    echo "Options:"
    echo "   apply-image-policy   Apply an image content source policy to use with a private registry"
    echo "   update-pull-secret   Update global cluster pull secret"
    echo "   add-ca-cert          Add a registry certificate authority to the cluster"
    echo "   delete-ca-cert       Delete a registry certificate authority from the cluster"
    echo "   -h, --help           Print usage information"
    echo ""
}

#
# Prints usage menu for 'apply-image-policy' action
#
print_cluster_apply_image_policy_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} cluster apply-image-policy --name POLICY_NAME"
    echo "       [--dry-run] [--image IMAGE|--csv IMAGE_CSV_FILE|--dir CASE_ARCHIVE_DIR]"
    echo "       [--ns-replace NAMESPACE|--ns-prefix PREFIX|--ns-suffix SUFFIX]"
    echo "       --registry TARGET_REGISTRY"
    echo ""
    echo "Apply an image content source policy to use with a mirrored registry"
    echo ""
    echo "Options:"
    echo "   -n, --name string     Policy name"
    echo "   --image string        A single image"
    echo "   --csv string          CASE images CSV file"
    echo "   --dir string          CASE archive directory that contains the image CSV files"
    echo "   --ns-replace string   Replace the namespace of the mirror image"
    echo "   --ns-prefix string    Append a prefix to the namespace of the mirror image"
    echo "   --ns-suffix string    Append a suffix to the namespace of the mirror image"       
    echo "   --registry string     The mirrored registry"
    echo "   --dry-run             Print the actions that would be taken"
    echo "   -h, --help            Print usage information"
    echo ""
    echo "Example:"
    echo "${script_name} cluster apply-image-policy --name cp-app --dry-run --dir ./offline --registry registry.example.com:5000"
    echo ""
}

#
# Prints usage menu for 'update-pull-secret' action
#
print_cluster_update_pull_secret_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} cluster update-pull-secret --registry TARGET_REGISTRY"
    echo ""
    echo "Update global cluster pull secret for a mirrored registry"
    echo ""
    echo "Options:"
    echo "   --registry string   The mirrored registry"   
    echo "   --dry-run           Print the actions that would be taken"
    echo "   -h, --help          Print usage information"
    echo ""
}

#
# Prints usage menu for 'add-ca-cert' action
#
print_cluster_add_ca_cert_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} cluster add-ca-cert --registry TARGET_REGISTRY"
    echo ""
    echo "Add the certificate authority of a target registry server to the cluster"
    echo ""
    echo "Options:"
    echo "   --registry string   The target registry"   
    echo "   --dry-run           Print the actions that would be taken"
    echo "   -h, --help          Print usage information"
    echo ""
}

#
# Prints usage menu for 'delete-ca-cert' action
#
print_cluster_delete_ca_cert_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} cluster delete-ca-cert --registry TARGET_REGISTRY"
    echo ""
    echo "Delete the certificate authority of a target registry server from the cluster"
    echo ""
    echo "Options:"
    echo "   --registry string   The target registry"   
    echo "   --dry-run           Print the actions that would be taken"
    echo "   -h, --help          Print usage information"
    echo ""
}

#
# Parses the CLI arguments for 'cluster' action
#
parse_cluster_arguments() {
    if [[ "$#" == 0 ]]; then
        print_cluster_usage
        exit 1
    fi

    # process options
    while [ "$1" != "" ]; do
        case "$1" in
        apply-image-policy)
            shift
            do_cluster_apply_image_policy "$@"
            break
            ;;
        update-pull-secret)
            shift
            do_cluster_update_pull_secret "$@"
            break
            ;;
        add-ca-cert)
            shift
            do_cluster_add_ca_cert "$@"
            break
            ;;
        delete-ca-cert)
            shift
            do_cluster_delete_ca_cert "$@"
            break
            ;;
        --dry-run)
            DRY_RUN="--dry-run"
            ;;
        -h | --help)
            print_cluster_usage
            exit 1
            ;;
        *)
            print_cluster_usage
            exit 1
            ;;
        esac
        shift
    done
}

#
# Parses the CLI arguments for 'apply-image-policy' action
#
parse_cluster_apply_image_policy_arguments() {
    if [[ "$#" == 0 ]]; then
        print_cluster_apply_image_policy_usage
        exit 1
    fi

    # process options
    while [ "$1" != "" ]; do
        case "$1" in
        -n | --name)
            shift
            IMAGE_POLICY_NAME="$1"
            ;;      
        --image)
            shift
            IMAGE="$1"
            ;;
        --csv)
            shift
            IMAGE_CSV_FILE="$1"
            ;;
        --dir)
            shift
            CASE_ARCHIVE_DIR="$1"
            ;;
        --ns-replace)
            shift
            NAMESPACE_ACTION="replace"
            NAMESPACE_ACTION_VALUE="$1"
            ;;
        --ns-prefix)
            shift
            NAMESPACE_ACTION="prefix"
            NAMESPACE_ACTION_VALUE="$1"
            ;;
        --ns-suffix)
            shift
            NAMESPACE_ACTION="suffix"
            NAMESPACE_ACTION_VALUE="$1"
            ;;
        --registry)
            shift   
            TARGET_REGISTRY="$1"
            ;;            
        --dry-run)            
            DRY_RUN="--dry-run"
            ;;
        -h | --help)
            print_cluster_apply_image_policy_usage
            exit 1
            ;;
        *)
            print_cluster_apply_image_policy_usage
            exit 1
            ;;
        esac
        shift
    done
}

#
# Parses the CLI arguments for 'update-pull-secret' action
#
parse_cluster_update_pull_secret_arguments() {
    if [[ "$#" == 0 ]]; then
        print_cluster_update_pull_secret_usage
        exit 1
    fi

    # process options
    while [ "$1" != "" ]; do
        case "$1" in
        --registry)
            shift   
            TARGET_REGISTRY="$1"
            ;;     
        --dry-run)            
            DRY_RUN="--dry-run"
            ;;
        -h | --help)
            print_cluster_update_pull_secret_usage
            exit 1
            ;;
        *)
            print_cluster_update_pull_secret_usage
            exit 1
            ;;
        esac
        shift
    done
}

#
# Parses the CLI arguments for 'add-ca-cert' action
#
parse_cluster_add_ca_cert_arguments() {
    if [[ "$#" == 0 ]]; then
        print_cluster_add_ca_cert_usage
        exit 1
    fi

    # process options
    while [ "$1" != "" ]; do
        case "$1" in
        --registry)
            shift   
            TARGET_REGISTRY="$1"
            ;;     
        --dry-run)            
            DRY_RUN="--dry-run"
            ;;
        -h | --help)
            print_cluster_add_ca_cert_usage
            exit 1
            ;;
        *)
            print_cluster_add_ca_cert_usage
            exit 1
            ;;
        esac
        shift
    done
}

#
# Parses the CLI arguments for 'delete-ca-cert' action
#
parse_cluster_delete_ca_cert_arguments() {
    if [[ "$#" == 0 ]]; then
        print_cluster_delete_ca_cert_usage
        exit 1
    fi

    # process options
    while [ "$1" != "" ]; do
        case "$1" in
        --registry)
            shift   
            TARGET_REGISTRY="$1"
            ;;     
        --dry-run)            
            DRY_RUN="--dry-run"
            ;;
        -h | --help)
            print_cluster_delete_ca_cert_usage
            exit 1
            ;;
        *)
            print_cluster_delete_ca_cert_usage
            exit 1
            ;;
        esac
        shift
    done
}

#
# Validates the CLI arguments for 'apply-image-policy' action
#
validate_cluster_apply_image_policy_arguments() {
    if [ -z "${IMAGE_POLICY_NAME}" ]; then
        echo "[ERROR] The policy name was not specified"
        exit 1
    fi

    if [ -z "${IMAGE}" ] && [ -z "${IMAGE_CSV_FILE}" ] && [ -z "${CASE_ARCHIVE_DIR}" ]; then
        echo "[ERROR] One of --image or --csv or --case-dir parameter must be specified"
        exit 1
    fi

    if [ ! -z "${IMAGE_CSV_FILE}" ] && [  ! -z "${CASE_ARCHIVE_DIR}" ]; then
        echo "[ERROR] Only --csv or --case-dir parameter should be specified"
        exit 1
    fi

    if [ ! -z "${IMAGE_CSV_FILE}" ] && [ ! -f "${IMAGE_CSV_FILE}" ]; then
        echo "[ERROR] Invalid image CSV file: ${IMAGE_CSV_FILE}"
        exit 1
    fi

    if [ ! -z "${CASE_ARCHIVE_DIR}" ] && [ ! -d "${CASE_ARCHIVE_DIR}" ]; then
        echo "[ERROR] Invalid CASE archive directory: ${CASE_ARCHIVE_DIR}"
        exit 1
    fi

    if [ ! -z "${NAMESPACE_ACTION}" ] && [ -z "${NAMESPACE_ACTION_VALUE}" ]; then
        echo "[ERROR] Missing an argument for namespace ${NAMESPACE_ACTION}"
        exit 1
    fi

    if [ -z "${TARGET_REGISTRY}" ]; then
        echo "[ERROR] The target registry was not specified"
        exit 1
    fi
}

#
# Validates the CLI arguments for 'update-pull-secret' action
#
validate_cluster_update_pull_secret_arguments() {
    if [ -z "${TARGET_REGISTRY}" ]; then
        echo "[ERROR] The target registry was not specified"
        exit 1
    fi

    if [ ! -f "${AUTH_DATA_PATH}/secrets/${TARGET_REGISTRY}.json" ]; then
        echo "[ERROR] Target registry authentication secret not found"
        exit 1
    fi
}

#
# Validates the CLI arguments for 'add-ca-cert' action
#
validate_cluster_add_ca_cert_arguments() {
    if [ -z "${TARGET_REGISTRY}" ]; then
        echo "[ERROR] The target registry was not specified"
        exit 1
    fi
}

#
# Validates the CLI arguments for 'delete-ca-cert' actions
#
validate_cluster_delete_ca_cert_arguments() {
    if [ -z "${TARGET_REGISTRY}" ]; then
        echo "[ERROR] The target registry was not specified"
        exit 1
    fi

    # checks for registries CAs configmap
    ca_configmap=$(oc -n openshift-config get configmap | grep "${REGISTRY_CA_CONFIGMAP}")
    if [ -z "${ca_configmap}" ]; then
        echo "[ERROR] Configmap ${REGISTRY_CA_CONFIGMAP} not found"
        exit 1
    fi

    # checks the existance of the ca cert
    registry_key=$(echo "${TARGET_REGISTRY}" | sed -e "s|:|..|")
    ca_cert=$(oc -n openshift-config get configmap "${REGISTRY_CA_CONFIGMAP}" -o jsonpath="{.data}" | grep "${registry_key}")

    if [ -z "${ca_cert}" ]; then
        echo "[ERROR] Certificate authority for ${TARGET_REGISTRY} not found"
        exit 11
    fi
}

# --- Run ---

main $*
