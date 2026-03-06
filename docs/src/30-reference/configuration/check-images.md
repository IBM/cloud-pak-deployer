# Image Access Validation (check_images)

## Overview

The Cloud Pak Deployer includes a pre-flight validation feature that verifies your IBM entitlement key has access to all required container images **before** deployment begins. This prevents deployment failures that would otherwise occur hours into the installation process.


### Key Features

- **Early Detection**: Catches authorization issues before deployment starts
- **Smart Sampling**: Validates 3 representative images per cartridge (configurable)
- **Fast Performance**: Validation completes in under 1 minute
- **Direct CASE File Reading**: Uses Ansible playbooks to read image lists directly from CASE CSV files
- **No cpd-cli Required**: Works without requiring cpd-cli container runtime
- **Clear Error Messages**: Provides actionable feedback with specific image names and resolution steps
- **Configurable**: Can be enabled/disabled or adjusted for speed vs. thoroughness

## Configuration

### Default Behavior

By default, image access validation is **enabled** and will **fail the deployment** if unauthorized images are detected.

### Configuration Options

Add the following to your `global_config` section:

```yaml
global_config:
  environment_name: my-environment
  cloud_platform: existing-ocp
  
  check_images:
    # Enable or disable validation (default: true)
    enabled: true
    
    # Fail deployment on validation errors (default: true)
    # Set to false to only warn
    fail_on_error: true
    
    # Number of sample images per component (default: 3)
    # Set to 'all' to check all images (slower but most thorough)
    # Higher = more thorough but slower
    sample_size: 3
```

### Example Configurations

#### Disable Validation (Air-gapped Environments)

```yaml
check_images:
  enabled: false
```

#### Warn Only (Don't Fail Deployment)

```yaml
check_images:
  enabled: true
  fail_on_error: false
  sample_size: 2
```

#### Check All Images (Maximum Coverage)

```yaml
check_images:
  enabled: true
  fail_on_error: true
  sample_size: all
```

#### Custom Sample Size

```yaml
check_images:
  enabled: true
  fail_on_error: true
  sample_size: 5
```

### Command-Line Override

You can override the configuration settings using the `--check-images` command-line option:

```bash
# Enable validation with default sample size (3 images per component)
./cp-deploy.sh env apply --check-images

# Disable validation (overrides YAML config)
./cp-deploy.sh env apply --check-images=false

# Check all images (overrides sample_size in YAML config)
./cp-deploy.sh env apply --check-images=all

# Check specific number of images per component (e.g., 5)
./cp-deploy.sh env apply --check-images=5
```

**Note:** The command-line option takes precedence over YAML configuration settings.

## How It Works

### Validation Process

1. **Retrieve Entitlement Key**: Gets `ibm_cp_entitlement_key` from vault
2. **Identify Components**: Determines which Cloud Pak components are being deployed
3. **Fetch Images Dynamically**: Uses `cpd-cli manage list-images` to get actual images from IBM
4. **Smart Sampling**: Selects a sample of images based on configured sample_size
5. **Validate Access**: Uses `skopeo inspect` to verify image access
6. **Report Results**: Displays clear success/failure messages

### Dynamic Image Discovery with cpd-cli

The validator uses the `cpd-cli manage list-images` command to dynamically fetch the actual images required for your deployment:

```bash
cpd-cli manage list-images \
  --release=5.0.0 \
  --components=cpfs,cpd_platform,ws,spss \
  --inspect_source_registry=true
```

### Smart Sampling Strategy

Instead of checking all images (which can take 10+ minutes), the validator samples images based on the `sample_size` configuration:

- **Default sample_size: 3** - Checks ~3 images per component
- **Configurable** - Increase for more thorough validation, decrease for faster checks
- **Automatic scaling** - Total images = sample_size × (number of components + 2)

This approach reduces validation time by **70-80%** while still catching entitlement issues.

## Error Messages

### Successful Validation

```
========================================
Image Access Validation Results
========================================
Total images checked: 12
Successful validations: 12
Failed validations: 0
========================================

✓ All 12 representative images are accessible with the provided entitlement key
```

### Failed Validation

```
========================================
ERROR: Image Access Authorization Failed
========================================

The entitlement key does not grant access to the following image(s):

Component: watsonx_ai
Image: cp.icr.io/cp/cpd/watsonx-ai-operator@sha256:a1a1a1a1...
Error: unauthorized: authentication required

Component: watson_discovery
Image: cp.icr.io/cp/cpd/watson-discovery-operator@sha256:d4d4d4d4...
Error: denied: You are not authorized to access this resource

RESOLUTION STEPS:
1. Verify your entitlement key is valid and not expired
2. Ensure the entitlement key includes permissions for:
   - watsonx_ai
   - watson_discovery
3. Check your entitlement at: https://myibm.ibm.com/products-services/containerlibrary
4. If needed, request additional entitlements from your IBM representative

For more information, see: https://www.ibm.com/docs/en/cloud-paks
========================================
```

## When Validation Runs

Validation runs during **Phase 10 - Validate**, immediately after variable validation and before any infrastructure provisioning or Cloud Pak installation.

**Playbook execution order:**
1. Load configuration
2. Validate variables
3. **→ Validate image access** ← New step
4. Lint configuration
5. Continue with deployment...

## Skipping Validation

Validation is automatically skipped in these scenarios:

- **Air-gapped deployments**: When `cpd_airgap: true`
- **No entitlement key**: When `ibm_cp_entitlement_key` is not found in vault
- **Explicitly disabled**: When `check_images.enabled: false`

## Troubleshooting

### No Images Found for Validation

If validation reports no images found:
1. Ensure cartridges have `state: installed` in your configuration
2. Check that CASE files exist in `cpd-cli-workspace/olm-utils-workspace/work/offline/{version}/.ibm-pak/data/cases/`
3. Verify the CP4D version is correctly specified

### Validation Takes Too Long

Reduce the sample size:
```yaml
check_images:
  sample_size: 2
```

### Need Complete Validation

Check all images instead of sampling:
```yaml
check_images:
  sample_size: all
```

### Network Issues

If validation fails due to network connectivity:
- Check firewall rules for `cp.icr.io` access
- Verify proxy settings if applicable
- Retry the deployment (validation includes automatic retries)

## Performance Comparison

| Validation Method | Time | Coverage |
|------------------|------|----------|
| No validation | 0s | 0% (fails during install) |
| Full validation (all images) | 10-15 min | 100% |
| **Smart sampling (default)** | **30-60s** | **~80%** |
