#! /bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

# --------------------------------------------------------------------------------------------------------- #
# Functions                                                                                                 #
# --------------------------------------------------------------------------------------------------------- #
command_usage() {
  echo
  echo "Usage: $0 SUBCOMMAND ACTION [OPTIONS]"
  echo
  echo "SUBCOMMAND:"
  echo "  environment,env           Apply configuration to create, modify or destroy an environment"
  echo "  vault                     Get, create, modify or delete secrets in the configured vault"
  echo "  help,h                    Show help"
  echo
  echo "ACTION:"
  echo "  environment:"
  echo "    apply                   Create a new or modify an existing environment"
  echo "    destroy                 Destroy an existing environment"
  echo "  vault:"
  echo "    get                     Get a secret from the vault and return its value"
  echo "    set                     Create or update a secret in the vault"
  echo "    delete                  Delete a secret from the vault"
  echo "    list                    List secrets for the specified vault group"
  echo
  echo "OPTIONS:"
  echo "Generic options (environment variable). You can specify the options on the command line or set an environment variable before running the $0 command:"
  echo "  --status-dir,-l <dir>         Local directory to store logs and other provisioning files (\$STATUS_DIR)"
  echo "  --config-dir,-c <dir>         Directory to read the configuration from. Must be specified if configuration read from local server (\$CONFIG_DIR)"
  echo "  --config-repo-url,-r <url>    Git repository to retrieve the configuration from (\$GIT_REPO_URL)"
  echo "  --git-repo-dir,-rd <dir>      Directory in the Git repository that holds the configuration (\$GIT_REPO_DIR)"
  echo "  --git-access-token,-t <token> Token to authenticate to the Git repository (\$GIT_ACCESS_TOKEN)"
  echo "  --ibm-cloud-api-key <apikey>  API key to authenticate to the IBM Cloud (\$IBM_CLOUD_API_KEY)"
  echo "  --confirm-destroy             Confirm that infra may be destroyed. Required for action destroy and when apply destroys infrastructure (\$CONFIRM_DESTROY)"
  echo "  --cpd-develop                 Map current directory to automation scripts, only for development/debug (\$CPD_DEVELOP)"
  echo "  -vvv                          Show verbose ansible output (\$ANSIBLE_VERBOSE)"
  echo
  echo "Options for vault subcommand:"
  echo "  --vault-group,-vg <name>          Group of secret (\$VAULT_GROUP)"
  echo "  --vault-secret,-vs <name>         Secret name to get, set or delete (\$VAULT_SECRET)"
  echo "  --vault-secret-value,-vsv <value> Secret value to set (\$VAULT_SECRET_VALUE)"
  echo
  exit $1
}

# --------------------------------------------------------------------------------------------------------- #
# Initialize                                                                                                #
# --------------------------------------------------------------------------------------------------------- #
if [ ! -v CPD_DEVELOP ];then CPD_DEVELOP=false;fi
if [ ! -v ANSIBLE_VERBOSE ];then ANSIBLE_VERBOSE=false;fi
if [ ! -v CONFIRM_DESTROY ];then CONFIRM_DESTROY=false;fi

# --------------------------------------------------------------------------------------------------------- #
# Check subcommand and action                                                                               #
# --------------------------------------------------------------------------------------------------------- #

# Check number of parameters
if [ "$#" -lt 2 ]; then
  command_usage
fi

# Check that subcommand is valid
export SUBCOMMAND=${1,,}
case "$SUBCOMMAND" in
env|environment)
  export SUBCOMMAND="environment"
  shift 1
  ;;
vault)
  shift 1
  ;;
h|help)
  command_usage 0
  ;;
*) 
  echo "Invalid subcommand."
  command_usage 1
  ;;
esac

# Check that action is valid for subcommand
export ACTION=${1,,}
case "$SUBCOMMAND" in
environment)
  case "$ACTION" in
  --help|-h)
    command_usage 0
    ;;
  apply|destroy)
    shift 1
    ;;
  *)
    echo "Invalid action for environment subcommand."
    command_usage 1
    ;;
  esac
  ;;
vault)
  case "$ACTION" in
  --help|-h)
    command_usage 0
    ;;
  get|set|delete|list)
    shift 1
    ;;
  *)
    echo "Invalid action for vault subcommand."
    command_usage 1
    ;;
  esac
  ;;
esac

# --------------------------------------------------------------------------------------------------------- #
# Parse remainder of the parameters and populate environment variables                                      #
# --------------------------------------------------------------------------------------------------------- #

# Parse parameters
PARAMS=""
while (( "$#" )); do
  case "$1" in
  --help|-h)
    command_usage 0
    ;;
  --config-dir*|-c*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export CONFIG_DIR="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export CONFIG_DIR=$2
      shift 2
    else
      echo "Error: Missing configuration directory for --config-dir parameter."
      command_usage 2
    fi
    fi
    ;;
  --git-repo-url*|-r*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export GIT_REPO_URL="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export GIT_REPO_URL=$2
      shift 2
    else
      echo "Error: Missing configuration git repository for --git-repo-url parameter."
      command_usage 2
    fi
    fi
    ;;
  --git-repo-dir*|-rd*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export GIT_REPO_DIR="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export GIT_REPO_DIR=$2
      shift 2
    else
      echo "Error: Missing configuration git repository directory for --git-repo-dir parameter."
      command_usage 2
    fi
    fi
    ;;
  --git-access-token*|-t*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export GIT_ACCESS_TOKEN="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export GIT_ACCESS_TOKEN=$2
      shift 2
    else
      echo "Error: Missing argument for --git-access-token parameter."
      command_usage 2
    fi
    fi
    ;;
  --ibm-cloud-api-key*|-k*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export IBM_CLOUD_API_KEY="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export IBM_CLOUD_API_KEY=$2
      shift 2
    else
      echo "Error: Missing argument for --ibm-cloud-api-key parameter."
      command_usage 2
    fi
    fi
    ;;
  --vault-secret-value*|-vsv*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_SECRET_VALUE="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_SECRET_VALUE=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-secret-value parameter."
      command_usage 2
    fi
    fi
    ;;
  # The --vault-secret must be parsed after --vault-secret-value, otherwise the secret value is already
  # picked up when the first part of the option has a match
  --vault-secret*|-vs*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_SECRET="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_SECRET=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-secret parameter."
      command_usage 2
    fi
    fi
    ;;
  --vault-group*|-vg*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_GROUP="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_GROUP=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-group parameter."
      command_usage 2
    fi
    fi
    ;;
  --status-dir*|-l*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export STATUS_DIR="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export STATUS_DIR=$2
      shift 2
    else
      echo "Error: Missing argument for --status-dir parameter."
      command_usage 2
    fi
    fi
    ;;
  --confirm-destroy)
    export CONFIRM_DESTROY=true
    shift 1
    ;;
  --cpd-develop)
    export CPD_DEVELOP=true
    shift 1
    ;;
  -vvv)
    export ANSIBLE_VERBOSE=true
    shift 1
    ;;
  -*|--*=)
    echo "Invalid option: $1"
    command_usage 2
    ;;
  *) # preserve remaining arguments
    PARAMS="$PARAMS $1"
    shift
    ;;
  esac
done
# --------------------------------------------------------------------------------------------------------- #
# Check invalid combinations of parameters                                                                  #
# --------------------------------------------------------------------------------------------------------- #
if [ -z ${CONFIG_DIR} ] && [ -z ${GIT_REPO_URL} ];then
  echo "Error: Either specify --config-dir or --git-repo-url."
  command_usage 1
fi

# Validate if the configuration directory exists and has the correct subdirectories
if [ ! -z ${CONFIG_DIR} ];then
  if [ ! -z ${GIT_REPO_URL} ];then
    echo "Error: Either specify --config-dir or --git-repo-url, not both."
    exit 1
  fi
  if [ ! -d "${CONFIG_DIR}/config" ]; then
    echo "config directory not found in directory ${CONFIG_DIR}."
    exit 1
  fi
  if [ ! -d "${CONFIG_DIR}/inventory" ]; then
    echo "inventory directory not found in directory ${CONFIG_DIR}."
    exit 1
  fi
fi

# Validate combination of parameters when --git-repo-url specified
if [ ! -z ${GIT_REPO_URL} ];then
  if [ -z ${GIT_REPO_DIR} ];then
    echo "Error: --git-repo-dir must be specified if pulling the configuration from a Git repository."
    exit 1
  fi
  if [ -z ${GIT_ACCESS_TOKEN} ];then
    echo "Error: --git-access-token must be specified if pulling the configuration from a Git repository."
    exit 1
  fi

fi

# Set remaining parameters
eval set -- "$PARAMS"

# --------------------------------------------------------------------------------------------------------- #
# The remainder of the parameters will be checked in the pod                                                #
# --------------------------------------------------------------------------------------------------------- #

# Check if podman command was found
if ! command -v podman &> /dev/null;then
  echo "podman command was not found."
  exit 99
fi

# Check if the cloud-pak-deployer image exists
if ! podman image exists cloud-pak-deployer;then
  echo "Container image cloud-pak-deployer does not exist on the local machine, please build first."
  exit 99
fi

# --------------------------------------------------------------------------------------------------------- #
# Run the Cloud Pak Deployer                                                                                #
# --------------------------------------------------------------------------------------------------------- #

# Show warning if --cpd-develop is used
if $CPD_DEVELOP;then
  echo "Warning: CPD_DEVELOP was specified. Current directory $(pwd) will be used for automation script !!!"
  sleep 0.5
fi

# Ensure status directory exists
if [ -z $STATUS_DIR ];then
  export STATUS_DIR=$(mktemp -d)
  echo "Status directory not specified, setting to $STATUS_DIR" >&2
fi
mkdir -p $STATUS_DIR

# Build command
run_cmd="podman run"

# If running "environment" subcommand, run as daemon
if [ "$SUBCOMMAND" == "environment" ];then
  run_cmd+=" -d"
fi

if [ "$SUBCOMMAND" == "vault" ];then
  run_cmd+=" --cap-add=IPC_LOCK"
fi

run_cmd+=" -v ${STATUS_DIR}:${STATUS_DIR}:Z "

if [ ! -z $CONFIG_DIR ];then run_cmd+=" -v ${CONFIG_DIR}:${CONFIG_DIR}:Z";fi
if $CPD_DEVELOP;then run_cmd+=" -v ${PWD}:/automation_script:Z";fi

run_cmd+=" -e SUBCOMMAND=${SUBCOMMAND}"
run_cmd+=" -e ACTION=${ACTION}"
run_cmd+=" -e STATUS_DIR=${STATUS_DIR}"
run_cmd+=" -e IBM_CLOUD_API_KEY=${IBM_CLOUD_API_KEY}"

if [ ! -z $CONFIG_DIR ];then run_cmd+=" -e CONFIG_DIR=${CONFIG_DIR}";fi

if [ ! -z $GIT_REPO_URL ];then
  run_cmd+=" -e GIT_REPO_URL=${GIT_REPO_URL} \
            -e GIT_REPO_DIR=${GIT_REPO_DIR} \
            -e GIT_ACCESS_TOKEN=${GIT_ACCESS_TOKEN}"
fi

if [ ! -z $VAULT_GROUP ];then
  run_cmd+=" -e VAULT_GROUP=${VAULT_GROUP} \
            -e VAULT_SECRET=${VAULT_SECRET} \
            -e VAULT_SECRET_VALUE=${VAULT_SECRET_VALUE}"
fi

run_cmd+=" -e ANSIBLE_VERBOSE=${ANSIBLE_VERBOSE}"
run_cmd+=" -e CONFIRM_DESTROY=${CONFIRM_DESTROY}"

run_cmd+=" cloud-pak-deployer"

eval $run_cmd

# If running "environment" subcommand, follow log
if [ "$SUBCOMMAND" == "environment" ];then
  podman logs -fl
fi

PODMAN_EXIT_CODE=$?
exit $PODMAN_EXIT_CODE

