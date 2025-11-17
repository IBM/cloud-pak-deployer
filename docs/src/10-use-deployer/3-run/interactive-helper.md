# Guided configuration with the Cloud Pak helper

The Cloud Pak Deployer ships an interactive helper script that collects all the
inputs normally needed for a manual installation (`CONFIG_DIR`, `STATUS_DIR`,
OpenShift access credentials, IBM entitlement key, and the Cloud Pak component
selection). The helper works for every Cloud Pak profile supported by the
deployer: Cloud Pak for Data & watsonx, Cloud Pak for Business Automation, and
Cloud Pak for Integration.

## When to use the helper

Use the helper whenever you want to:

- bootstrap a brand new configuration directory without hand-editing YAML
- update an existing configuration by stepping through a guided questionnaire
- switch between Cloud Pak profiles from the same workstation while keeping the
  environment structure consistent

You can still rely on a GitOps flow or edit the YAML files directly. However,
the helper reduces the chance of typos and keeps the workspace predictable,
which is especially useful for new users or when creating many environments.

## Running the helper

``` { .bash .copy }
python3 cp-deploy-helper/cpd_helper.py
```

### Helper workflow

1. **Workspace selection** – choose or confirm the base directory where the
   helper stores its internal `helper-state.json`, the `configuration/`
   directory (for `CONFIG_DIR`), the `status/` directory (for `STATUS_DIR`), and
   the generated `set-env.sh` script.

2. **Cloud Pak profile** – pick one of the profiles. Previously generated
   answers are loaded automatically, so you can tweak the same configuration
   later without re-entering everything.

3. **OpenShift settings** – provide the cluster version, name, domain, storage
   class, and whether to enable OpenShift Data Foundation (MCG).

4. **Credentials and entitlement** – enter the OpenShift API endpoint, user,
   password/token, and the IBM entitlement key. The helper stores these only in
   the workspace-local `set-env.sh` and helper state file (permissions are
   restricted to the current user).

5. **Profile-specific questionnaire**:
   - *Cloud Pak for Data & watsonx*: choose entitlements and cartridges from a
     curated list. Required cartridges remain selected, optional cartridges can
     be toggled individually or in bulk.
   - *Cloud Pak for Business Automation*: enable or disable each pattern
     (Decisions, Workflow, Document Processing, etc.) and helper services such
     as Process Mining, RPA, AKHQ, or CloudBeaver. The helper auto-fills the
     CR customization blocks.
   - *Cloud Pak for Integration*: pick the integration instances (Navigator, App
     Connect, API Connect, Event Streams, MQ, and more) and define whether to
     use the top-level operator along with its channel and CASE version.

6. **Generation** – the helper writes `configuration/config/cpd-config.yaml`
   aligned with the selected profile, updates the helper state, and refreshes
   the workspace `set-env.sh`.

### Resulting workspace layout

```
<helper-workspace>/
├── configuration/        # use as CONFIG_DIR (contains config/cpd-config.yaml)
├── status/               # use as STATUS_DIR
├── helper-state.json     # helper state (user-only permissions)
└── set-env.sh            # exports CONFIG_DIR/STATUS_DIR and sensitive values
```

After reviewing the YAML file you can simply source the environment script and
run the deployer:

``` { .bash .copy }
source <helper-workspace>/set-env.sh
./cp-deploy.sh env apply --accept-all-licenses
```

### Updating existing configurations

Re-run the helper at any time to change your Cloud Pak selection, adjust
OpenShift settings, or rotate credentials. The script merges the new answers
with the stored state so that only the fields you modify are rewritten.
