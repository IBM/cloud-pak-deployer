#! /bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

pathmunge () {
    case ":${PATH}:" in
        *:"$1":*)
            ;;
        *)
            if [ "$2" = "after" ] ; then
                PATH=$PATH:$1
            else
                PATH=$1:$PATH
            fi
    esac
}

echo "Setting Cloud Pak Deployer environment with directory ${SCRIPT_DIR}"

alias cp-deploy.sh=${SCRIPT_DIR}/cp-deploy.sh

pathmunge ${SCRIPT_DIR}/scripts/cp4d after
pathmunge ${SCRIPT_DIR}/scripts/deployer after

unset pathmunge