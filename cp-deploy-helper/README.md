# Cloud Pak Deployer helper

`cpd_helper.py` guides you through the configuration that is normally entered
manually before running `cp-deploy.sh`. The helper:

- prompts for the configuration and status directory, OpenShift details and
  IBM entitlement key
- lets you choose which Cloud Pak profile you want to install (watsonx, Cloud Pak
  for Data & Software Hub, Cloud Pak for Integration, Cloud Pak for Business
  Automation, or Cloud Pak for Watson AIOps)
- dynamically builds a `config/cpd-config.yaml` file that contains the OpenShift
  section plus the Cloud Pak profile you selected
- provides curated menus for CP4D cartridges, CP4BA patterns/add-ons, and CP4I
  instances so that required components remain selected
- regenerates the configuration later on by reusing the stored helper state

## Usage

```bash
python3 cp-deploy-helper/cpd_helper.py
```

The wizard walks through the following flow:

1. Pick (or create) a workspace directory. The helper stores its `helper-state.json`
   next to the generated `configuration/`, `status/`, and `set-env.sh`.
2. Enter the paths for `CONFIG_DIR` and `STATUS_DIR`. The helper ensures the
   directories exist so the deployer can reuse them.
3. Select the Cloud Pak profile to configure. You can re-run the helper later
   to switch profiles or adjust an existing configuration; previous answers are
   pre-populated.
4. Provide the OpenShift API URL, user, password/token, and the IBM entitlement key.
5. Complete the profile-specific wizard:
   - **watsonx:** choose the entitlements and cartridges to install for
     watsonx.ai, watsonx.data, watsonx.governance, and watsonx Code Assistant.
     Required cartridges are locked, optional ones can be toggled from the menu.
   - **Cloud Pak for Data & Software Hub:** pick the Cloud Pak for Data cartridges,
     including Software Hub workloads, that you want to deploy.
   - **Cloud Pak for Business Automation:** toggle each pattern (decisions, workflow,
     document processing…) and the additional helper services (Process Mining,
     RPA, helper UIs).
   - **Cloud Pak for Integration:** select the integration instances (Navigator,
     App Connect, API Connect, Event Streams, MQ, etc.) and configure whether
     the top-level operator should manage them.
   - **Cloud Pak for Watson AIOps:** choose which instances (AI Manager, Event
     Manager, Turbonomic, Instana, Infrastructure, demo content) to install and
     let the wizard generate the corresponding instance definitions.
6. Confirm the wizard summary. The helper writes `configuration/config/cpd-config.yaml`
   and a workspace-specific `set-env.sh`. Sensitive data such as entitlement keys
   and OpenShift credentials are stored only in `helper-state.json` and
   `set-env.sh` with user-only permissions.

Re-running the script will re-open the existing helper state so you can edit any
value without touching the YAML manually.

The helper keeps secrets (OpenShift credentials and entitlement key) in the
generated `set-env.sh` file. That file is marked read-only for the current user,
but you must still handle it carefully and clean it up if it should not remain
on the machine.
