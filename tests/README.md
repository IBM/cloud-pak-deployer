# Tests

Run all commands from the repository root.

## Test tiers

| Tier | Command | Needs |
|---|---|---|
| **Unit tests** | `bash tests/ibm-bob/run_unit_tests.sh` | Python with `python-benedict`, `pyyaml` |
| **Container checks** | `bash tests/ibm-bob/run_container_tests.sh` | Deployer image `cloud-pak-deployer:latest`, podman or docker |
| **Integration** | `./cp-deploy.sh test [--mode <mode>]` | Deployer image, real OpenShift cluster, vault secrets (see below) |

Unit tests can also be run inside the deployer container when the host Python lacks `benedict`:

```bash
podman run --rm -v $PWD:/cloud-pak-deployer -w /cloud-pak-deployer --entrypoint bash \
  localhost/cloud-pak-deployer:latest -c "bash tests/ibm-bob/run_unit_tests.sh"
```

## Integration test

`cp-deploy.sh test` discovers harnesses under `tests/*/run_integration_tests.sh`, builds the vault secrets from environment variables (`CPD_OC_LOGIN`, `CP_ENTITLEMENT_KEY`) and delegates to each matching harness. All harnesses share the gitignored run directory `tests/test-run/` — config templates are copied there on every run and never modified; the vault, logs and downloads persist between runs.

The harness runs on the host and calls `./cp-deploy.sh env apply|download`, so the tests run the real deployer. The deployer code under test is the code built into the image; after changing a role or playbook, run `./cp-deploy.sh build` before `./cp-deploy.sh test`. The deployer log is `tests/test-run/status/log/cloud-pak-deployer.log`.

Podman on macOS only shares paths under `$HOME`, so the repository must be under `$HOME`.

### Mode syntax

| Argument | What runs |
|---|---|
| _(none)_ | All harnesses, mode `full` |
| `<mode>` | All harnesses, that mode |
| `ibm_bob:<mode>` | IBM Bob harness only |
| `ibm_bob:<mode>,<mode>,...` | IBM Bob harness only, several modes in sequence (see below) |

The IBM Bob harness accepts a comma-separated list of modes, run in the given order; it stops at the first failure. `full` can be used inside a list and expands to its sequence. Examples:

```bash
./cp-deploy.sh test --mode ibm_bob:airgap-full,remove,airgap-semi,remove
./cp-deploy.sh test --mode ibm_bob:install,smoke,remove
```

Credential checks (entitlement key) cover the whole list up front, so a missing secret fails before anything runs. A list is the way to resume a `full` run after a failure: start the list at the phase that failed. The `cp4d` harness takes a single mode.

### One-time vault setup

`oc-login` and `ibm_cp_entitlement_key` are passed as environment variables on every run — no vault setup needed for them. The table below lists the secrets that must be stored once.

`vault set` uses the shared config at `tests/config/` and requires absolute paths for `-c` and `-l`. Run from the repository root:

```bash
# IBM Bob — optional, only needed when ingress_cert is enabled in the test configurations
# (tests/ibm-bob/config/*.yaml).
# Use the email address that should receive Let's Encrypt expiry notifications.
# The cluster's apps domain must be publicly reachable for the HTTP-01 challenge.
./cp-deploy.sh vault set \
  -vs=ibm_bob_acme_email=<email> \
  -c $PWD/tests -l $PWD/tests/test-run/status

# IBM Bob — airgap-full, airgap-semi and full only (one-time per cluster)
# <name> is a short label, e.g. it-registry; the credentials are user:password.
# The registry must allow nested repository paths (for example cp/bob/bob-gateway), so the
# OpenShift internal registry cannot be used: it only accepts <project>/<name>.
# Use a registry such as IBM Cloud Container Registry, Quay or Harbor. The URL must include
# the namespace/organization that the images are pushed to, for example
# https://de.icr.io/<namespace>
./cp-deploy.sh vault set \
  -vs=image_registry_name=<name> \
  -vs=image_registry_url=https://<registry-host>/<namespace> \
  -vs=image-registry-<name>=<user>:<password> \
  -c $PWD/tests -l $PWD/tests/test-run/status
```

Alternatively, export `ACME_EMAIL=<email>` before running `cp-deploy.sh test` to skip the vault lookup (only relevant when ACME is enabled).

Then on every run export the two per-run credentials and call `cp-deploy.sh test`:

```bash
export CPD_OC_LOGIN="oc login https://api.<cluster>.<domain>:6443 -u kubeadmin -p <password> --insecure-skip-tls-verify"
export CP_ENTITLEMENT_KEY=<key>
./cp-deploy.sh test
```

---

## Shared cleanup

`tests/lib/test-cleanup.yml` is shared by all harnesses. It removes the shared infrastructure that the tests install (cert-manager, OpenShift AI, NFD, NVIDIA GPU operator; safe if absent) so the cluster is clean for the next run. It runs as the last step of `full`, and can be run on its own with `ibm_bob:cleanup`. It needs only `oc-login`.

## IBM Bob (`tests/ibm-bob/`)

| Mode | What it does |
|---|---|
| `dry-run` | Validate config and render `config.yaml`; no cluster changes |
| `install` | Full install + smoke tests + certificate assertions |
| `smoke` | Post-install check only; no changes |
| `remove` | Uninstall Bob; cert-manager and OpenShift AI are left in place; removal assertions |
| `airgap-full` | Fully air-gapped: mirror images, vLLM image and model weights entitled→portable (local directory)→private registry, install and check; asserts that every container in the Bob and operators namespaces and the vLLM ServingRuntime images use the private registry |
| `airgap-semi` | Semi air-gapped: mirror directly entitled→private registry (no local directory), install and check; same registry assertion |
| `cleanup` | Remove shared infrastructure (cert-manager, OpenShift AI, NFD, NVIDIA GPU operator); needs only `oc-login`, no entitlement key |
| `full` | `dry-run → install → remove → airgap-full → remove → airgap-semi → remove → cleanup`; stops at first failure |

Config templates: `tests/ibm-bob/config/`. For a non-standard environment (storage class, project, Bob version) edit the templates before running.

For a full cycle starting clean, run `ibm_bob:remove` first if needed, then `./cp-deploy.sh test`.
