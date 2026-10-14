# IBM Bob tests

Run all commands from the repository root. None of them is called by CI yet; each is written so that it can be.

| Test Suite | Command | Needs | What it checks |
|---|---|---|---|
| **Unit tests** | `bash tests/ibm-bob/run_unit_tests.sh` | Python with `python-benedict`, `pyyaml` (present in deployer container) | Preprocessor validation, version table, `config.yaml` template |
| **Dry-run & syntax** | `bash tests/ibm-bob/run_dry_run_tests.sh` | Deployer image `cloud-pak-deployer:latest`, podman or docker | `--check-only` for the `ibm-bob`, `cp4d` and `cp4i` samples, `ansible-playbook --syntax-check` of touched playbooks (~10 min). |
| **Integration (optional)** | `IBM_BOB_IT_ENABLE=true IBM_BOB_IT_KUBECONFIG=<file> bash tests/ibm-bob/run_integration_tests.sh` | Real OpenShift cluster, deployer image | Prerequisites, `config.yaml`, install and smoke tests against that cluster |

On workstations where the host Python lacks `benedict`, unit tests can be run inside the deployer container:

```bash
podman run --rm -v $PWD:/cloud-pak-deployer -w /cloud-pak-deployer --entrypoint bash localhost/cloud-pak-deployer:latest -c "bash tests/ibm-bob/run_unit_tests.sh"
```

## Integration test

There is no cluster that is always available, so the integration test is opt-in and fully configured through environment variables. Without `IBM_BOB_IT_ENABLE=true` it prints a message and exits 0.
It runs in the deployer container with a throw-away file vault, so nothing is read from or written to a real vault.

Modes (`IBM_BOB_IT_MODE`):

* `dry-run` (default): prerequisites and `config.yaml` rendering with `cpd_dry_run=true`. Changes nothing on the cluster.
* `install`: the above without dry-run, so the full install and wait for Ready, then the smoke tests. Needs `CP_ENTITLEMENT_KEY`. **Changes the cluster**, and installs the Red Hat cert-manager operator if the cluster has none.
* `smoke`: only the stage 80 smoke tests and access report, against a cluster where Bob is already installed. Changes nothing on the cluster except writing a vault secret to the throw-away vault.
* `remove`: runs `state: removed` via `ibm-bob-cluster`, then the stage 80 smoke tests to confirm both namespaces are gone. **Changes the cluster** — removes the Bob instance. Use this to clean up after `install` before running an air-gapped test.
* `airgap`: full air-gapped flow — mirrors images from the IBM entitled registry to a local filesystem (`entitled-to-portable`), then uploads them to a private registry (`portable-to-private`), then runs a full install with `cpd_airgap=true`, then the smoke tests. **Changes the cluster**. Requires `CP_ENTITLEMENT_KEY`, `IBM_BOB_IT_REGISTRY_CREDS`, and `IBM_BOB_IT_REGISTRY_URL`.

The header of [`run_integration_tests.sh`](run_integration_tests.sh) lists all variables (storage type or storage classes, project names, version, `rag`, `reuse_existing_cert_manager`, status dir, image). The cluster and domain name are derived from the **current context** of the kubeconfig, because the deployer refuses to work on a cluster whose API URL does not contain `<cluster>.<domain>`.
The status dir (default `$HOME/.cpd-ibm-bob-it`) is kept between runs so that the Bob bundle is only downloaded once. The image filesystem cache from `entitled-to-portable` is also stored in the status dir, so `portable-to-private` does not need to re-download from `cp.icr.io`.

Example against a cluster where Bob is not installed yet:

```bash
IBM_BOB_IT_ENABLE=true IBM_BOB_IT_KUBECONFIG=$HOME/kubeconfig \
IBM_BOB_IT_MODE=install CP_ENTITLEMENT_KEY=<key> \
  bash tests/ibm-bob/run_integration_tests.sh
```

Air-gapped test (run `remove` first to clear any existing connected install):

```bash
# Step 1: remove any existing connected install
IBM_BOB_IT_ENABLE=true IBM_BOB_IT_KUBECONFIG=$HOME/kubeconfig \
IBM_BOB_IT_MODE=remove \
  bash tests/ibm-bob/run_integration_tests.sh

# Step 2: run the full air-gapped flow
IBM_BOB_IT_ENABLE=true IBM_BOB_IT_KUBECONFIG=$HOME/kubeconfig \
IBM_BOB_IT_MODE=airgap \
  CP_ENTITLEMENT_KEY=<ibm-entitlement-key> \
  IBM_BOB_IT_REGISTRY_URL=https://de.icr.io/bob-on-prem \
  IBM_BOB_IT_REGISTRY_CREDS=iamapikey:<api_key> \
    bash tests/ibm-bob/run_integration_tests.sh
```

Negative cases (unknown storage name, unsupported OCP version, leftover cert-manager CRDs without controller) can be verified manually by supplying invalid values for the environment variables above.
