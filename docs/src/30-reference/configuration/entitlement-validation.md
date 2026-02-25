# Entitlement Image Validation

## Overview

The Cloud Pak Deployer includes a pre-flight validation feature that verifies your IBM entitlement key has access to all required container images **before** deployment begins. This prevents deployment failures that would otherwise occur hours into the installation process.

**Reference:** [GitHub Issue #1085](https://github.com/IBM/cloud-pak-deployer/issues/1085)

## Problem Statement

Previously, the deployer only validated entitlement key credentials through a login test (e.g., `skopeo login cp.icr.io`). However, successful login does not guarantee that the entitlement key has permission to pull specific images required for deployment.

Common scenario:
```bash
podman login cp.icr.io → Login Succeeded ✓
podman pull cp.icr.io/cp/cpd/<image>@sha256:<digest> → denied: You are not authorized ✗
```

This resulted in deployments failing hours later during Software Hub or component installation.

## Solution

The deployer now performs **smart sampling validation** during the validation phase (playbook 10), checking access to representative images for each Cloud Pak component before any installation begins.

### Key Features

- **Early Detection**: Catches authorization issues before deployment starts
- **Smart Sampling**: Validates 2-3 representative images per component instead of all images
- **Fast Performance**: Reduces validation time from 10+ minutes to under 1 minute
- **Clear Error Messages**: Provides actionable feedback with specific image names and resolution steps
- **Configurable**: Can be enabled/disabled or configured to warn instead of fail

## Configuration

### Default Behavior

By default, entitlement validation is **enabled** and will **fail the deployment** if unauthorized images are detected.

### Configuration Options

Add the following to your `global_config` section:

```yaml
global_config:
  environment_name: my-environment
  cloud_platform: existing-ocp
  
  entitlement_validation:
    # Enable or disable validation (default: true)
    enabled: true
    
    # Fail deployment on validation errors (default: true)
    # Set to false to only warn
    fail_on_error: true
    
    # Number of sample images per component (default: 3)
    # Higher = more thorough but slower
    sample_size: 3
```

### Example Configurations

#### Disable Validation (Air-gapped Environments)

```yaml
entitlement_validation:
  enabled: false
```

#### Warn Only (Don't Fail Deployment)

```yaml
entitlement_validation:
  enabled: true
  fail_on_error: false
  sample_size: 2
```

#### Maximum Validation Coverage

```yaml
entitlement_validation:
  enabled: true
  fail_on_error: true
  sample_size: 5
```

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

**Benefits of this approach:**
- **Always Up-to-Date**: Gets current images directly from IBM, no hardcoded templates
- **Version-Aware**: Automatically uses correct images for your CP4D version
- **Component-Specific**: Only checks images for components you're actually deploying
- **Future-Proof**: Automatically includes new images as Cloud Paks evolve

**Requirements:**
- `cpd-cli` must be installed and available in PATH
- Internet connection to IBM Container Registry
- Valid IBM entitlement key

For cpd-cli installation, see: [IBM Documentation - List Images](https://www.ibm.com/docs/en/software-hub/5.1.x?topic=manage-list-images)

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
Entitlement Image Validation Results
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
ERROR: Entitlement Key Authorization Failed
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
3. **→ Validate entitlement images** ← New step
4. Lint configuration
5. Continue with deployment...

## Skipping Validation

Validation is automatically skipped in these scenarios:

- **Air-gapped deployments**: When `cpd_airgap: true`
- **No entitlement key**: When `ibm_cp_entitlement_key` is not found in vault
- **Explicitly disabled**: When `entitlement_validation.enabled: false`
- **cpd-cli not available**: When `cpd-cli` is not installed or not in PATH

## Troubleshooting

### cpd-cli Not Available

If you see "cpd-cli is NOT available" message:
1. Install cpd-cli from: https://www.ibm.com/docs/en/software-hub/5.1.x?topic=manage-list-images
2. Ensure cpd-cli is in your PATH
3. Verify installation: `cpd-cli version`
4. Alternatively, disable validation: `entitlement_validation.enabled: false`

### Validation Takes Too Long

Reduce the sample size:
```yaml
entitlement_validation:
  sample_size: 2
```

### cpd-cli Command Fails

If `cpd-cli manage list-images` fails:
1. Check your internet connection
2. Verify IBM_ENTITLEMENT_KEY is set correctly
3. Ensure you're using a compatible cpd-cli version
4. Check cpd-cli logs for detailed error messages

### False Positives

If validation fails but you believe your entitlement is correct:
1. Verify the entitlement key at https://myibm.ibm.com/products-services/containerlibrary
2. Check for typos in the vault secret
3. Ensure the key hasn't expired
4. Temporarily set `fail_on_error: false` to continue deployment

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

## Best Practices

1. **Keep validation enabled** for online deployments
2. **Use default sample_size (3)** for balanced speed and coverage
3. **Check entitlements early** before starting long deployments
4. **Update entitlement keys** before they expire
5. **Disable only for air-gapped** environments

## Related Documentation

- [Vault Configuration](vault.md)
- [Global Configuration](global-config.md)
- [IBM Container Library](https://myibm.ibm.com/products-services/containerlibrary)
- [GitHub Issue #1085](https://github.com/IBM/cloud-pak-deployer/issues/1085)