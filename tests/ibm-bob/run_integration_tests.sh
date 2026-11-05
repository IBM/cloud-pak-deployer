#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# tests/ibm-bob/run_integration_tests.sh
#
# Live integration test of IBM Bob against a real OpenShift cluster. Normally started
# through the deployer:
#
#   ./cp-deploy.sh test --mode ibm_bob:<mode>
#
# which exports MODE, CPD_IMAGE_TAG, CPD_CONTAINER_ENGINE, CP_ENTITLEMENT_KEY and
# VAULT_SECRETS (the oc-login secret from CPD_OC_LOGIN) to this script. It can also be
# run directly: MODE=install bash tests/ibm-bob/run_integration_tests.sh
#
# Modes (MODE):
#   dry-run  validate the configuration and render config.yaml; no cluster changes
#   install  full install and wait for Ready, then smoke test and live assertions
#   smoke    post-install check only; no cluster changes
#   remove   uninstall Bob (cert-manager and OpenShift AI stay), then live assertions
#   airgap-full  fully air-gapped: entitled-to-portable (local directory) -> portable-to-private
#                -> install -> check
#   airgap-semi  semi air-gapped: entitled-to-private (direct mirror, no local directory)
#                -> install -> check
#   cleanup  remove shared infrastructure (cert-manager, OpenShift AI, NFD, NVIDIA GPU operator)
#   full     dry-run -> install -> remove -> airgap-full -> remove -> airgap-semi -> remove
#            -> cleanup (default); stops at the first failure
#
# MODE can also be a comma-separated list, run in the given order and stopping at the first
# failure, for example:
#   ./cp-deploy.sh test --mode ibm_bob:airgap-full,remove,airgap-semi,remove
# "full" may be used inside a list and expands to its sequence above.
#
# Secrets all live in the vault (see tests/README.md):
#   oc-login, ibm_cp_entitlement_key                      all modes except dry-run
#   image-registry-<name>, image_registry_name,
#   image_registry_url                                    airgap-full, airgap-semi and full
# ---------------------------------------------------------------------------
set -euo pipefail

PRODUCT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/it-common.sh
source "${PRODUCT_DIR}/../lib/it-common.sh"

# ---- Per-phase state read by run_playbook ------------------------------------
DRY_RUN=false
CONFIRM_DESTROY=false
AIRGAP=false
REGISTRY_EXTRA=""

# ---- Checks ------------------------------------------------------------------
# MODE is one mode or a comma-separated list; "full" expands to its sequence.
FULL_SEQUENCE="dry-run install remove airgap-full remove airgap-semi remove cleanup"
MODES=()
IFS=',' read -r -a REQUESTED_MODES <<< "${MODE}"
for m in "${REQUESTED_MODES[@]}"; do
  case "${m}" in
    full)
      read -r -a FULL_MODES <<< "${FULL_SEQUENCE}"
      MODES+=("${FULL_MODES[@]}") ;;
    dry-run|install|smoke|remove|airgap-full|airgap-semi|cleanup) MODES+=("${m}") ;;
    *) die "MODE must be a comma-separated list of full, dry-run, install, smoke, remove, airgap-full, airgap-semi or cleanup, got '${MODE}'" ;;
  esac
done
[ ${#MODES[@]} -gt 0 ] || die "no mode specified"

needs_entitlement=false
for m in "${MODES[@]}"; do
  case "${m}" in dry-run|smoke|remove|cleanup) ;; *) needs_entitlement=true ;; esac
done

if [ "${needs_entitlement}" = true ]; then
  if [ -z "${CP_ENTITLEMENT_KEY:-}" ] && ! vault_has "ibm_cp_entitlement_key"; then
    die "no entitlement key: set CP_ENTITLEMENT_KEY or vault secret ibm_cp_entitlement_key (see tests/README.md)"
  fi
fi

# ACME is disabled in the test configurations for now (ingress_cert is commented out), so
# acme_email is optional. When it is set in the vault secret ibm_bob_acme_email or the
# ACME_EMAIL environment variable, it is passed on for configurations that use it.
ACME_EMAIL="${ACME_EMAIL:-}"
if [ -z "${ACME_EMAIL}" ] && vault_has "ibm_bob_acme_email"; then
  ACME_EMAIL="$(vault_get ibm_bob_acme_email)"
fi
ACME_EXTRA=""
[ -z "${ACME_EMAIL}" ] || ACME_EXTRA="-e acme_email=${ACME_EMAIL}"

it_check_common
it_reset_config

# ---- Configuration -----------------------------------------------------------
use_bob_config() {
  rm -f "${CONFIG_YAML_DIR}/it-bob.yaml"
  cp "${PRODUCT_DIR}/config/$1" "${CONFIG_YAML_DIR}/it-bob.yaml"
  echo "Active IBM Bob configuration: $1"
}

# ---- Playbook runner ---------------------------------------------------------
# Wraps it_run_playbook with the IBM Bob-specific DRY_RUN / CONFIRM_DESTROY / AIRGAP flags.
# $1 playbook name (under tests/ibm-bob/playbooks/), $2 optional extra ansible args.
run_playbook() {
  local playbook="$1" extra="${2:-}"
  local bool_yaml="cpd_dry_run: ${DRY_RUN}
confirm_destroy: ${CONFIRM_DESTROY}
cpd_airgap: ${AIRGAP}"
  it_run_playbook \
    "tests/ibm-bob/playbooks/${playbook}" \
    "-e IT_DRY_RUN=${DRY_RUN} -e IT_CONFIRM_DESTROY=${CONFIRM_DESTROY} -e IT_AIRGAP=${AIRGAP} -e CPD_AIRGAP=${AIRGAP}" \
    "${bool_yaml}" \
    "${REGISTRY_EXTRA} ${extra}"
}

show_info() {
  echo "Access info:"
  cat "${STATUS_DIR}/cloud-paks/cloud-pak-deployer-info.txt" || true
}

# ---- Phases ------------------------------------------------------------------
phase_dry_run() {
  use_bob_config it-bob-install.yaml
  DRY_RUN=true
  run_playbook test-cluster-live.yml "${ACME_EXTRA}"
  DRY_RUN=false
}

phase_install() {
  use_bob_config it-bob-install.yaml
  run_playbook test-cluster-live.yml "${ACME_EXTRA}"
  run_playbook test-smoke-live.yml "${ACME_EXTRA}"
  show_info
  run_playbook test-assert-live.yml "-e it_assert_phase=install ${ACME_EXTRA}"
}

phase_smoke() {
  use_bob_config it-bob-install.yaml
  run_playbook test-smoke-live.yml "${ACME_EXTRA}"
  show_info
}

phase_remove() {
  use_bob_config it-bob-remove.yaml
  CONFIRM_DESTROY="$(awk '/^[[:space:]]*confirm_destroy:/ {print tolower($2); exit}' "${CONFIG_YAML_DIR}/it-bob.yaml")"
  CONFIRM_DESTROY="${CONFIRM_DESTROY:-false}"
  run_playbook test-uninstall-live.yml "${ACME_EXTRA}"
  CONFIRM_DESTROY=false
  run_playbook test-assert-live.yml "-e it_assert_phase=remove ${ACME_EXTRA}"
}

# $1 flavour: full (via portable directory) or semi (direct mirror)
phase_airgap() {
  local flavour="$1" name
  for secret in image_registry_name image_registry_url; do
    vault_has "${secret}" || die "vault secret ${secret} is required for airgap (see tests/README.md)"
  done
  name="$(vault_get image_registry_name)"
  vault_has "image-registry-${name}" || die "vault secret image-registry-${name} is required for airgap (see tests/README.md)"
  use_bob_config it-bob-airgap.yaml
  REGISTRY_EXTRA="-e image_registry_name=${name} -e image_registry_url=$(vault_get image_registry_url)"
  AIRGAP=true
  run_playbook "test-airgap-${flavour}-live.yml" "${ACME_EXTRA}"
  show_info
  # The registry placeholders in the configuration must still resolve, so assert before the reset.
  run_playbook test-assert-live.yml "-e it_assert_phase=airgap ${ACME_EXTRA}"
  AIRGAP=false
  REGISTRY_EXTRA=""
}

phase_cleanup() {
  it_reset_config
  it_run_playbook "tests/lib/test-cleanup.yml" \
    "" \
    "cpd_dry_run: false
confirm_destroy: false
cpd_airgap: false"
}

# Bash reads a script command by command while it executes it, so editing this file during a
# long run could break the run. The phases therefore run inside a function, and the call and
# the exit are on one line: bash has read everything it needs before the first phase starts
# and reads nothing from the file after main returns.
main() {
  echo "IBM Bob integration test, mode: ${MODE} (${MODES[*]}), run directory: ${RUN_DIR}"
  local step=0 m
  for m in "${MODES[@]}"; do
    step=$((step + 1))
    echo "=== IBM Bob integration test, step ${step}/${#MODES[@]}: ${m} ==="
    case "${m}" in
      dry-run) phase_dry_run ;;
      install) phase_install ;;
      smoke)   phase_smoke ;;
      remove)  phase_remove ;;
      airgap-full) phase_airgap full ;;
      airgap-semi) phase_airgap semi ;;
      cleanup) phase_cleanup ;;
    esac
  done

  echo "=== IBM Bob integration test (${MODE}) passed ==="
}

main; exit $?
