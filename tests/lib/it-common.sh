#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# tests/lib/it-common.sh
#
# Shared setup sourced by every harness's run_integration_tests.sh.
# Source this file AFTER defining PRODUCT_DIR and VALID_MODES in the caller.
#
# Provides:
#   Variables  REPO_ROOT, RUN_DIR, CONFIG_DIR, CONFIG_YAML_DIR, STATUS_DIR,
#              ENVIRONMENT_NAME, VAULT_FILE, MODE, ENGINE, IMAGE, ARCH, IMAGE_ARCH
#   Functions  die, vault_has, vault_get, it_check_common, it_reset_config,
#              it_run_playbook
# ---------------------------------------------------------------------------

# ---- Paths ------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[1]}")/../.." && pwd)"
RUN_DIR="${REPO_ROOT}/tests/test-run"
CONFIG_DIR="${RUN_DIR}"
CONFIG_YAML_DIR="${CONFIG_DIR}/config"
STATUS_DIR="${RUN_DIR}/status"
ENVIRONMENT_NAME="integration-tests"
VAULT_FILE="${STATUS_DIR}/vault/${ENVIRONMENT_NAME}"

# ---- Runtime ----------------------------------------------------------------
MODE="${MODE:-full}"
ENGINE="${CPD_CONTAINER_ENGINE:-$(command -v podman >/dev/null 2>&1 && echo podman || echo docker)}"
IMAGE="localhost/cloud-pak-deployer:${CPD_IMAGE_TAG:-latest}"

ARCH="$(uname -m)"
if [ "${ARCH}" = "amd64" ]; then ARCH="x86_64"; fi
if [ "${ARCH}" = "x86_64" ] || [ "${ARCH}" = "arm64" ]; then IMAGE_ARCH="amd64"; else IMAGE_ARCH="${ARCH}"; fi

# ---- Helpers ----------------------------------------------------------------
die()       { echo "ERROR: $*" >&2; exit 2; }
vault_has() { [ -f "${VAULT_FILE}" ] && grep -q "^$1=" "${VAULT_FILE}"; }
vault_get() { grep "^$1=" "${VAULT_FILE}" | head -1 | cut -d= -f2- | (base64 -d 2>/dev/null || base64 -D); }

# it_check_common
#   Validates the engine, image, run-dir location, creates dirs, and checks
#   the oc-login secret. Call after the MODE validity check in the harness.
it_check_common() {
  command -v "${ENGINE}" >/dev/null 2>&1 || die "container engine ${ENGINE} not found"
  ${ENGINE} image inspect "${IMAGE}" >/dev/null 2>&1 \
    || die "deployer image ${IMAGE} not found, build it first (./cp-deploy.sh build)"
  case "${RUN_DIR}" in
    "${HOME}"/*) ;;
    *) echo "WARNING: ${RUN_DIR} is not under \$HOME; podman on macOS only shares paths under \$HOME." ;;
  esac

  mkdir -p "${CONFIG_YAML_DIR}" "${STATUS_DIR}"

  if ! vault_has "oc-login" && ! [[ "${VAULT_SECRETS:-}" == *'"oc-login"'* ]]; then
    die "no oc-login secret: run with CPD_OC_LOGIN set through ./cp-deploy.sh test, or set it once with ./cp-deploy.sh vault set (see tests/README.md)"
  fi
}

# it_reset_config
#   Clears the run config directory and copies the shared it-ocp.yaml into it.
#   Call once per run, before any use_<product>_config calls.
it_reset_config() {
  rm -f "${CONFIG_YAML_DIR}"/*.yaml
  cp "${REPO_ROOT}/tests/config/it-ocp.yaml" "${CONFIG_YAML_DIR}/it-ocp.yaml"
}

# it_run_playbook <playbook_path> [extra_docker_envs] [bool_yaml] [extra_ansible_args]
#
#   <playbook_path>      full path relative to /cloud-pak-deployer inside the container,
#                        e.g. "tests/ibm-bob/playbooks/test-cluster-live.yml"
#   [extra_docker_envs]  additional space-separated -e KEY=VAL flags for docker/podman run,
#                        e.g. "-e IT_DRY_RUN=true -e IT_AIRGAP=false"
#   [bool_yaml]          YAML string of boolean variables written to a file and loaded with
#                        -e @file, e.g. "cpd_dry_run: false\nconfirm_destroy: false".
#                        Ansible -e @file parses YAML types correctly (unlike -e key=value
#                        which always yields strings).
#   [extra_ansible_args] additional ansible-playbook -e string arguments
it_run_playbook() {
  local playbook="$1"
  local extra_docker="${2:-}"
  local bool_yaml="${3:-}"
  local extra_ansible="${4:-}"
  echo "=== ${playbook} ==="
  # shellcheck disable=SC2086
  ${ENGINE} run --rm --arch "${IMAGE_ARCH}" \
    -v "${REPO_ROOT}:/cloud-pak-deployer" \
    -v "${RUN_DIR}:${RUN_DIR}" \
    -e CP_ENTITLEMENT_KEY -e VAULT_SECRETS \
    -e ACTION=apply -e CPD_ACCEPT_LICENSES=false \
    -e CONFIG_DIR="${CONFIG_DIR}" -e STATUS_DIR="${STATUS_DIR}" \
    -e ARCH="${ARCH}" -e IMAGE_ARCH="${IMAGE_ARCH}" \
    -e IT_PLAYBOOK="${playbook}" \
    -e IT_EXTRA="${extra_ansible}" \
    -e IT_BOOL_YAML="${bool_yaml}" \
    ${extra_docker} \
    -w /cloud-pak-deployer --entrypoint bash "${IMAGE}" -c '
      source ./scripts/deployer/set-env-var.sh > /dev/null
      export ANSIBLE_CONFIG=/cloud-pak-deployer/ansible.cfg
      # Redirect the ansible log to a unique timestamped file so nested ansible-playbook
      # invocations (e.g. olm-utils list-components) do not contend on /tmp/ansible.log.
      export ANSIBLE_LOG_PATH="${STATUS_DIR}/log/ansible-it-$(date +%s).log"
      # Write boolean flags into a YAML file so ansible-playbook parses them as real
      # booleans. -e key=value always yields strings; -e @file parses YAML types correctly.
      printf "%s\n" "${IT_BOOL_YAML}" > /tmp/it-bool-vars.yaml
      ansible-playbook "${IT_PLAYBOOK}" \
        -e cpd_action=apply -e "config_dir=${CONFIG_DIR}" -e "status_dir=${STATUS_DIR}" \
        -e generators_dir=/cloud-pak-deployer/automation-generators -e _deployer_dir=/cloud-pak-deployer \
        -e ibmcloud_api_key= -e secret_group_param= -e "cp_entitlement_key=${CP_ENTITLEMENT_KEY:-}" \
        -e cpd_optimize_deploy=false -e cpd_skip_infra=true -e cp_config_only=false -e cpd_check_only=false \
        -e cpd_skip_mirror=false -e cpd_skip_cp_install=false -e cpd_skip_portable_registry=false \
        -e cpd_test_cartridges=false -e cpd_accept_licenses=false \
        -e "ARCH=${ARCH}" -e "IMAGE_ARCH=${IMAGE_ARCH}" -e "OLM_UTILS_IMAGE=${OLM_UTILS_IMAGE:-}" \
        -e @/tmp/it-bool-vars.yaml \
        ${IT_EXTRA}'
}
