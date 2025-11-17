# Cloud Pak Deployer helper

`cpd_helper.py` guides you through the configuration that is normally entered
manually before running `cp-deploy.sh`. The helper:

- prompts for the configuration and status directory, OpenShift details and
  IBM entitlement key
- dynamically builds a `config/cpd-config.yaml` file that contains both the
  OpenShift and Cloud Pak for Data configuration blocks
- lets you pick the Cloud Pak for Data cartridges from a curated list, while
  ensuring that required cartridges are always present
- regenerates the configuration later on by reusing the stored helper state

## Usage

```bash
python3 cp-deploy-helper/cpd_helper.py
```

The wizard stores the helper state alongside the generated directories so that
re-running the script will allow you to edit any value without opening the YAML
files manually.

The helper keeps secrets (OpenShift credentials and entitlement key) in the
generated `set-env.sh` file. That file is marked read-only for the current user,
but you must still handle it carefully and clean it up if it should not remain
on the machine.
