#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# tests/lib/it-common.sh
#
# Shared setup sourced by every harness's run_integration_tests.sh. The harness runs on the
# host; install, remove, smoke and download steps go through ./cp-deploy.sh (it_deployer),
# the deployer code under test is the code built into the deployer image.
# Source this file AFTER defining PRODUCT_DIR and VALID_MODES in the caller.
#
# Provides:
#   Variables  REPO_ROOT, RUN_DIR, CONFIG_DIR, CONFIG_YAML_DIR, STATUS_DIR,
#              ENVIRONMENT_NAME, VAULT_FILE, MODE, ENGINE, IMAGE, ARCH, IMAGE_ARCH
#   Functions  die, vault_has, vault_get, it_check_common, it_reset_config,
#              it_deployer, it_version_info, it_run_playbook
# ---------------------------------------------------------------------------

# ---- Paths ------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[1]}")/../.." && pwd)"
RUN_DIR="${REPO_ROOT}/tests/test-run"
CONFIG_DIR="${RUN_DIR}/cpd-config"
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

# it_deployer <apply|download> [cp-deploy.sh options...]
#
#   Runs ./cp-deploy.sh env <action> against the run directory, the same way a user would.
#   Always passed: -c <run dir> -l <run dir>/status --skip-infra -v
#     -v selects ansible.cfg (default callback, full output); without it most output is hidden.
#   Never pass --clean-up: cp-deploy.sh starts apply and download detached and reads the exit
#   code of the stopped container; with --clean-up the container is gone and the code is lost.
#   The stopped container is removed here instead. The exit code of cp-deploy.sh is returned.
#   CPD_CONTAINER_ENGINE, CPD_IMAGE_TAG, CPD_OC_LOGIN and CP_ENTITLEMENT_KEY come from the
#   environment (exported by ./cp-deploy.sh test).
it_deployer() {
  local action="$1" rc=0 container_id
  shift
  echo "=== cp-deploy.sh env ${action} $* ==="
  CPD_CONTAINER_ENGINE="${ENGINE}" CPD_IMAGE_TAG="${CPD_IMAGE_TAG:-latest}" \
    "${REPO_ROOT}/cp-deploy.sh" env "${action}" \
      -c "${CONFIG_DIR}" -l "${STATUS_DIR}" --skip-infra -v "$@" || rc=$?
  if [ -f "${STATUS_DIR}/pid/container.id" ]; then
    container_id="$(cat "${STATUS_DIR}/pid/container.id")"
    [ -z "${container_id}" ] || ${ENGINE} rm -f "${container_id}" >/dev/null 2>&1 || true
    rm -f "${STATUS_DIR}/pid/container.id"
  fi
  return ${rc}
}

# it_version_info
#   Prints the commit the deployer image was built from. The roles and playbooks under test
#   are the image version, the harness and the test configs are the working-tree version.
it_version_info() {
  echo "Deployer image ${IMAGE} was built from:"
  ${ENGINE} run --rm --arch "${IMAGE_ARCH}" --entrypoint cat "${IMAGE}" \
    /cloud-pak-deployer/.version-info/version-info.sh | sed 's/^/  /' \
    || echo "  (version info not available)"
}

# it_run_playbook <playbook_path> [extra_ansible_args]
#
#   Runs one of the test playbooks (assert, cleanup) that have no deployer equivalent, in a
#   container of the deployer image. Only tests/ (read-only) and the run directory are mounted:
#   the roles used by the playbook are the ones built into the image.
#
#   <playbook_path>      path relative to /cloud-pak-deployer inside the container,
#                        e.g. "tests/ibm-bob/playbooks/test-assert-live.yml"
#   [extra_ansible_args] additional ansible-playbook arguments, e.g. "-e it_assert_phase=install"
it_run_playbook() {
  local playbook="$1"
  local extra_ansible="${2:-}"
  echo "=== ${playbook} ==="
  # shellcheck disable=SC2086
  ${ENGINE} run --rm --arch "${IMAGE_ARCH}" \
    -v "${REPO_ROOT}/tests:/cloud-pak-deployer/tests:ro" \
    -v "${RUN_DIR}:${RUN_DIR}" \
    -e CP_ENTITLEMENT_KEY -e VAULT_SECRETS \
    -e CONFIG_DIR="${CONFIG_DIR}" -e STATUS_DIR="${STATUS_DIR}" \
    -e IT_PLAYBOOK="${playbook}" \
    -e IT_EXTRA="${extra_ansible}" \
    -w /cloud-pak-deployer --entrypoint bash "${IMAGE}" -c '
      export ANSIBLE_CONFIG=/cloud-pak-deployer/ansible.cfg
      # Timestamped log file so nested ansible-playbook invocations do not contend on /tmp/ansible.log.
      mkdir -p "${STATUS_DIR}/log"
      export ANSIBLE_LOG_PATH="${STATUS_DIR}/log/ansible-it-$(date +%s).log"
      # cpd_dry_run is read as a boolean by the deployer roles: pass it as JSON, not key=value.
      ansible-playbook "${IT_PLAYBOOK}" \
        -e "config_dir=${CONFIG_DIR}" -e "status_dir=${STATUS_DIR}" \
        -e generators_dir=/cloud-pak-deployer/automation-generators \
        -e secret_group_param= \
        -e "{\"cpd_dry_run\": false}" \
        ${IT_EXTRA}'
}
