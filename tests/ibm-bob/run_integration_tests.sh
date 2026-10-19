#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# tests/ibm-bob/run_integration_tests.sh
#
# OPTIONAL integration test against a real OpenShift cluster. It does nothing
# unless IBM_BOB_IT_ENABLE=true, and every cluster detail comes from environment
# variables, so it can be run against whichever cluster is available at the time
# (locally or from a CI job that supplies the variables as secrets).
#
# What it runs, inside the deployer container, with a throw-away file vault:
#   mode=dry-run (default): prerequisites + config.yaml rendering (cpd_dry_run=true). Changes
#                           nothing on the cluster; the cert-manager install and readiness checks
#                           are skipped, so a cluster without cert-manager still passes.
#   mode=install          : the above, then the full install and wait for Ready,
#                           then the stage 80 smoke tests / access report.
#   mode=smoke            : only the stage 80 smoke tests / access report, against a cluster
#                           where Bob is already installed. Changes nothing on the cluster.
#   mode=remove           : uninstall an existing Bob instance (state=removed), then verify
#                           both namespaces are absent via the stage 80 smoke tests.
#   mode=airgap           : full air-gapped flow: entitled-to-portable mirroring, then
#                           portable-to-private upload, then install with cpd_airgap=true,
#                           then the stage 80 smoke tests. Requires CP_ENTITLEMENT_KEY and
#                           IBM_BOB_IT_REGISTRY_CREDS / IBM_BOB_IT_REGISTRY_URL.
#
# Required environment variables
#   IBM_BOB_IT_ENABLE=true      explicit opt-in
#   IBM_BOB_IT_KUBECONFIG       path to a kubeconfig with cluster-admin (must be under $HOME
#                               when using podman on macOS)
#   CP_ENTITLEMENT_KEY          IBM entitlement key (only needed for mode=install/airgap)
#
# Additional variables required for mode=airgap
#   IBM_BOB_IT_REGISTRY_CREDS   private registry credentials in "user:password" format
#                               (e.g. "iamapikey:<api_key>")
#   IBM_BOB_IT_REGISTRY_URL     full registry URL including namespace path used when mirroring
#                               (e.g. "https://de.icr.io/bob-on-prem")
#   IBM_BOB_IT_REGISTRY_NAME    image_registry_name key (default: bob-mirror)
#
# Optional environment variables (defaults in brackets)
#   IBM_BOB_IT_MODE             dry-run | install | smoke | remove | airgap  [dry-run]
#   IBM_BOB_IT_VERSION          ibm_bob_version                            [latest]
#   IBM_BOB_IT_STORAGE_TYPE     openshift_storage.storage_type             [auto]
#                               (auto, odf, nfs, ibm-storage-fusion-hci, ...)
#   IBM_BOB_IT_STORAGE_CLASS_FILE / IBM_BOB_IT_STORAGE_CLASS_BLOCK
#                               override the detected RWX / RWO storage classes
#   IBM_BOB_IT_CLUSTER_NAME / IBM_BOB_IT_DOMAIN_NAME
#                               the deployer only works on a cluster when <cluster>.<domain> is part of the
#                               API server URL (https://api.<cluster>.<domain>:6443). Derived from the
#                               current context of the kubeconfig when not set; set both if the URL
#                               has a different shape. The current context is the one that is used.
#   IBM_BOB_IT_PROJECT          instance namespace                         [ibm-bob]
#   IBM_BOB_IT_OPERATORS_PROJECT operator namespace                        [<project>-operators]
#   IBM_BOB_IT_RAG              true to enable the rag premium package     [false]
#   IBM_BOB_IT_Z_PROXY          true to enable the z_proxy premium package [false]
#   IBM_BOB_IT_UNDERSTAND       true to enable understand premium package  [false]
#   IBM_BOB_IT_PREMIUM_ALL      true to enable all premium packages        [false]
#   IBM_BOB_IT_REUSE_CERT_MANAGER true to set reuse_existing_cert_manager  [false]
#   IBM_BOB_IT_STATUS_DIR       status dir, kept after the run             [$HOME/.cpd-ibm-bob-it]
#   IBM_BOB_IT_IMAGE            deployer image                             [localhost/cloud-pak-deployer:latest]
#   CPD_CONTAINER_ENGINE        podman | docker                            [podman if installed]
#
# Example:
#   IBM_BOB_IT_ENABLE=true IBM_BOB_IT_KUBECONFIG=$HOME/kubeconfig \
#     bash tests/ibm-bob/run_integration_tests.sh
# ---------------------------------------------------------------------------
set -euo pipefail

if [ "${IBM_BOB_IT_ENABLE:-false}" != "true" ]; then
  echo "IBM Bob integration test skipped (set IBM_BOB_IT_ENABLE=true and IBM_BOB_IT_KUBECONFIG to run it)."
  exit 0
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="${IBM_BOB_IT_MODE:-dry-run}"
ENGINE="${CPD_CONTAINER_ENGINE:-$(command -v podman >/dev/null 2>&1 && echo podman || echo docker)}"
IMAGE="${IBM_BOB_IT_IMAGE:-localhost/cloud-pak-deployer:latest}"
STATUS_DIR="${IBM_BOB_IT_STATUS_DIR:-${HOME}/.cpd-ibm-bob-it}"

die() { echo "ERROR: $*" >&2; exit 2; }

case "${MODE}" in dry-run|install|smoke|remove|airgap) ;; *) die "IBM_BOB_IT_MODE must be dry-run, install, smoke, remove or airgap, got '${MODE}'" ;; esac
[ -n "${IBM_BOB_IT_KUBECONFIG:-}" ] || die "IBM_BOB_IT_KUBECONFIG is required"
[ -f "${IBM_BOB_IT_KUBECONFIG}" ] || die "kubeconfig ${IBM_BOB_IT_KUBECONFIG} not found"
if [ "${MODE}" = "install" ] && [ -z "${CP_ENTITLEMENT_KEY:-}" ]; then
  die "CP_ENTITLEMENT_KEY is required for IBM_BOB_IT_MODE=install"
fi
if [ "${MODE}" = "airgap" ]; then
  [ -n "${CP_ENTITLEMENT_KEY:-}" ]          || die "CP_ENTITLEMENT_KEY is required for IBM_BOB_IT_MODE=airgap"
  [ -n "${IBM_BOB_IT_REGISTRY_CREDS:-}" ]   || die "IBM_BOB_IT_REGISTRY_CREDS is required for IBM_BOB_IT_MODE=airgap"
  [ -n "${IBM_BOB_IT_REGISTRY_URL:-}" ]     || die "IBM_BOB_IT_REGISTRY_URL is required for IBM_BOB_IT_MODE=airgap"
fi
command -v "${ENGINE}" >/dev/null 2>&1 || die "container engine ${ENGINE} not found"
${ENGINE} image inspect "${IMAGE}" >/dev/null 2>&1 || die "deployer image ${IMAGE} not found, build it first"

# Quick reachability check with the host oc when available; the real checks run in the container.
if command -v oc >/dev/null 2>&1; then
  KUBECONFIG="${IBM_BOB_IT_KUBECONFIG}" oc version >/dev/null 2>&1 || die "cannot reach the cluster with ${IBM_BOB_IT_KUBECONFIG}"
fi

mkdir -p "${STATUS_DIR}"
# Every run starts with a fresh vault; the status dir keeps the downloaded bundle between runs.
rm -rf "${STATUS_DIR}/vault" "${STATUS_DIR}/openshift" "${STATUS_DIR}/cloud-paks"
echo "Mode: ${MODE}   Status dir: ${STATUS_DIR}"

# Variables for the playbooks (no secrets in here)
IBM_BOB_IT_MODE="${MODE}" IBM_BOB_IT_KUBECONFIG="${IBM_BOB_IT_KUBECONFIG}" \
IBM_BOB_IT_REGISTRY_URL="${IBM_BOB_IT_REGISTRY_URL:-}" IBM_BOB_IT_REGISTRY_NAME="${IBM_BOB_IT_REGISTRY_NAME:-bob-mirror}" \
IBM_BOB_IT_SAMPLE_CONFIG="${IBM_BOB_IT_SAMPLE_CONFIG:-}" REPO_ROOT="${REPO_ROOT}" \
python3 - "${STATUS_DIR}/it-vars.json" <<'EOF'
import json, os, re, sys, yaml
e = os.environ.get
def flag(name):
    return e(name, 'false').lower() in ('true', 'yes', '1')
cluster_name, domain_name = e('IBM_BOB_IT_CLUSTER_NAME'), e('IBM_BOB_IT_DOMAIN_NAME')
if not (cluster_name and domain_name):
    # Use the API server of the kubeconfig's current context (a kubeconfig can hold many clusters)
    with open(e('IBM_BOB_IT_KUBECONFIG')) as f:
        kc = yaml.safe_load(f)
    ctx = next((c['context'] for c in kc.get('contexts', []) if c['name'] == kc.get('current-context')), {})
    server = next((c['cluster']['server'] for c in kc.get('clusters', []) if c['name'] == ctx.get('cluster')), '')
    m = re.match(r'https?://api\.([^.:/]+)\.([^:/\s]+)', server)
    if not m:
        sys.exit("Cannot derive the cluster and domain name from the current context server URL '{}', "
                 "set IBM_BOB_IT_CLUSTER_NAME and IBM_BOB_IT_DOMAIN_NAME".format(server))
    cluster_name, domain_name = cluster_name or m.group(1), domain_name or m.group(2)
mode = e('IBM_BOB_IT_MODE', 'dry-run')
project = e('IBM_BOB_IT_PROJECT', 'ibm-bob')
storage = {'storage_name': 'it-storage', 'storage_type': e('IBM_BOB_IT_STORAGE_TYPE', 'auto')}
if e('IBM_BOB_IT_STORAGE_CLASS_FILE'):
    storage['ocp_storage_class_file'] = e('IBM_BOB_IT_STORAGE_CLASS_FILE')
if e('IBM_BOB_IT_STORAGE_CLASS_BLOCK'):
    storage['ocp_storage_class_block'] = e('IBM_BOB_IT_STORAGE_CLASS_BLOCK')
bob = {
    'project': project,
    'operators_project': e('IBM_BOB_IT_OPERATORS_PROJECT', project + '-operators'),
    'openshift_cluster_name': cluster_name,
    'ibm_bob_version': e('IBM_BOB_IT_VERSION', 'latest'),
    'state': 'removed' if mode == 'remove' else 'installed',
}
# Storage and install options are only needed when not removing
if mode != 'remove':
    bob['openshift_storage_name'] = 'it-storage'
    bob['accept_licenses'] = True
    bob['reuse_existing_cert_manager'] = flag('IBM_BOB_IT_REUSE_CERT_MANAGER')
    bob['premium_packages'] = {
        'rag': flag('IBM_BOB_IT_PREMIUM_ALL') or flag('IBM_BOB_IT_RAG'),
        'z_proxy': flag('IBM_BOB_IT_PREMIUM_ALL') or flag('IBM_BOB_IT_Z_PROXY'),
        'understand': flag('IBM_BOB_IT_PREMIUM_ALL') or flag('IBM_BOB_IT_UNDERSTAND'),
    }

# Load sample config or model gateway if specified
sample_cfg = e('IBM_BOB_IT_SAMPLE_CONFIG')
if sample_cfg and mode != 'remove':
    cfg_path = sample_cfg if os.path.isabs(sample_cfg) else os.path.join(e('REPO_ROOT', '.'), sample_cfg)
    if os.path.exists(cfg_path):
        with open(cfg_path) as f:
            cfg = yaml.safe_load(f)
            if 'ibm_bob' in cfg and isinstance(cfg['ibm_bob'], list) and len(cfg['ibm_bob']) > 0:
                sb = cfg['ibm_bob'][0]
                if 'model_gateway' in sb:
                    bob['model_gateway'] = sb['model_gateway']
                if 'model_gateway_secret_names' in sb:
                    bob['model_gateway_secret_names'] = sb['model_gateway_secret_names']
                if 'premium_packages' in sb and not (flag('IBM_BOB_IT_PREMIUM_ALL') or flag('IBM_BOB_IT_RAG') or flag('IBM_BOB_IT_Z_PROXY') or flag('IBM_BOB_IT_UNDERSTAND')):
                    bob['premium_packages'] = sb['premium_packages']
# Air-gapped mode: attach image_registry_name and the registry entry to all_config
registry_url = e('IBM_BOB_IT_REGISTRY_URL', '')
registry_name = e('IBM_BOB_IT_REGISTRY_NAME', 'bob-mirror')
image_registry = []
if mode == 'airgap' and registry_url:
    bob['image_registry_name'] = registry_name
    image_registry = [{'name': registry_name, 'registry_url': registry_url, 'registry_insecure': False}]
all_config = {
    'openshift': [{'name': cluster_name, 'cluster_name': cluster_name, 'domain_name': domain_name,
                   'ocp_version': 'detect', 'openshift_storage': [storage]}],
}
if image_registry:
    all_config['image_registry'] = image_registry
data = {
    'status_dir': '/it/status',
    'environment_name': 'it-env',
    'cloud_platform': 'existing-ocp',
    'cpd_dry_run': mode == 'dry-run',
    'cpd_airgap': mode == 'airgap',
    'vault': {'vault_type': 'file-vault'},
    'all_config': all_config,
    'current_ibm_bob_cluster': bob,
}
with open(sys.argv[1], 'w') as f:
    json.dump(data, f, indent=2)
EOF

run_playbook() {
  local playbook="$1"
  echo "=== ${playbook} ==="
  ${ENGINE} run --rm \
    -v "${REPO_ROOT}:/cloud-pak-deployer" \
    -v "${STATUS_DIR}:/it/status" \
    -v "${IBM_BOB_IT_KUBECONFIG}:/it/kubeconfig:ro" \
    -e CP_ENTITLEMENT_KEY \
    -e IBM_BOB_IT_REGISTRY_CREDS \
    -e IBM_BOB_IT_REGISTRY_NAME \
    -w /cloud-pak-deployer --entrypoint bash "${IMAGE}" \
    -c "ANSIBLE_CONFIG=/cloud-pak-deployer/ansible.cfg ansible-playbook tests/ibm-bob/${playbook} -e @/it/status/it-vars.json"
}

run_playbook it-seed-vault.yml
if [ "${MODE}" = "remove" ]; then
  run_playbook test-uninstall-live.yml
elif [ "${MODE}" = "smoke" ]; then
  run_playbook test-smoke-live.yml
  echo "Access info:"
  cat "${STATUS_DIR}/cloud-paks/cloud-pak-deployer-info.txt"
elif [ "${MODE}" = "airgap" ]; then
  run_playbook test-airgap-live.yml
  echo "Access info:"
  cat "${STATUS_DIR}/cloud-paks/cloud-pak-deployer-info.txt"
else
  # dry-run or install
  run_playbook test-cluster-live.yml
  if [ "${MODE}" = "install" ]; then
    run_playbook test-smoke-live.yml
    echo "Access info:"
    cat "${STATUS_DIR}/cloud-paks/cloud-pak-deployer-info.txt"
  fi
fi

echo "=== IBM Bob integration test (${MODE}) passed ==="
