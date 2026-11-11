#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# tests/ibm-bob/run_container_tests.sh
#
# Container-level validation: deployer image required, no OpenShift cluster needed.
#   1. ./cp-deploy.sh env apply --check-only (config validation + generation, stages 10 and 20)
#      for the IBM Bob sample configs, plus the cp4d and cp4i samples as a regression
#      check for the shared cp-cert-manager role.
#   2. ansible-playbook --syntax-check on the touched playbooks.
#
# Run from anywhere:
#   bash tests/ibm-bob/run_container_tests.sh
#
# Requirements: the container image cloud-pak-deployer:latest has been built, and
# podman or docker is available. With podman on macOS the machine only shares paths
# under $HOME, so the temporary config and status dirs are created there.
# ---------------------------------------------------------------------------
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SAMPLES="${REPO_ROOT}/sample-configurations/sample-dynamic/config-samples"
ENGINE="${CPD_CONTAINER_ENGINE:-$(command -v podman >/dev/null 2>&1 && echo podman || echo docker)}"
export CPD_CONTAINER_ENGINE="${ENGINE}"

WORK_DIR="$(mktemp -d "${HOME}/.cpd-ibm-bob-dry-run.XXXXXX")"
trap 'rm -rf "${WORK_DIR}"' EXIT

FAILED=0

check_only() {
  local sample="$1"
  local cfg="${WORK_DIR}/${sample}/config" status="${WORK_DIR}/${sample}/status"
  mkdir -p "${cfg}" "${status}"
  cp "${SAMPLES}/ocp-existing-ocp.yaml" "${SAMPLES}/${sample}.yaml" "${cfg}/"
  echo "--- check-only: ocp-existing-ocp + ${sample}"
  if (cd "${REPO_ROOT}" && ./cp-deploy.sh env apply --check-only --accept-all-licenses --cpd-develop \
        -c "${WORK_DIR}/${sample}" -l "${status}" > "${WORK_DIR}/${sample}.log" 2>&1) \
     && grep -Eq "failed=0" "${WORK_DIR}/${sample}.log"; then
    echo "PASS ${sample}"
  else
    echo "FAIL ${sample} (last lines of the log follow)"
    tail -30 "${WORK_DIR}/${sample}.log"
    FAILED=1
  fi
}

# $1 playbook path relative to the repository root, without .yml
syntax_check() {
  local playbook="$1" logname="${1//\//_}"
  echo "--- syntax-check: ${playbook}"
  if ${ENGINE} run --rm -v "${REPO_ROOT}:/cloud-pak-deployer" -w /cloud-pak-deployer \
        --entrypoint bash cloud-pak-deployer:latest \
        -c "ANSIBLE_CONFIG=/cloud-pak-deployer/ansible.cfg ansible-playbook --syntax-check ${playbook}.yml -e status_dir=/tmp -e environment_name=x" \
        > "${WORK_DIR}/${logname}.log" 2>&1; then
    echo "PASS ${playbook}"
  else
    echo "FAIL ${playbook}"
    tail -30 "${WORK_DIR}/${logname}.log"
    FAILED=1
  fi
}

echo "=== IBM Bob Dry-Run — check-only validation ==="
for sample in ibm-bob-201 ibm-bob-latest cp4d-latest cp4i-latest; do
  check_only "${sample}"
done

echo "=== IBM Bob Syntax Checks — ansible playbooks ==="
for playbook in playbook-env-apply-50-install-cloud-pak playbook-env-apply-80-smoke-tests playbook-env-apply playbook-env-apply-cp-config-only playbook-env-download; do
  syntax_check "playbooks/${playbook}"
done
for playbook in tests/ibm-bob/playbooks/test-assert-live; do
  syntax_check "${playbook}"
done

if [ "${FAILED}" -ne 0 ]; then
  echo "=== Container checks FAILED ==="
  exit 1
fi
echo "=== All container checks passed ==="
