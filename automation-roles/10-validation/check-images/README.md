# Check Images Role

This role validates that the IBM entitlement key has access to required container images before deployment.

## Configuration

Configure via `global_config.check_images` in your configuration file:

```yaml
global_config:
  check_images:
    enabled: true              # Enable/disable image validation (default: false)
    fail_on_error: true        # Fail deployment if validation fails (default: true)
    sample_size: 3             # Number of images to test per cartridge (default: 3)
```

**Note**: Image validation is **disabled by default** to avoid impacting existing deployments. Enable it explicitly in your configuration.

## How It Works

The role validates `sample_size` images per installed cartridge:
- **4 cartridges × 3 images = 12 images validated**
- **10 cartridges × 3 images = 30 images validated**

This scales automatically with your deployment size.

## Examples

### Default Configuration
```yaml
global_config:
  check_images:
    enabled: true
    sample_size: 3
```
Result: **3 images per cartridge**

### More Thorough Validation
```yaml
global_config:
  check_images:
    enabled: true
    sample_size: 5
```
Result: **5 images per cartridge**

### Quick Validation
```yaml
global_config:
  check_images:
    enabled: true
    sample_size: 1
```
Result: **1 image per cartridge** (fastest)

### Disable Validation
```yaml
global_config:
  check_images:
    enabled: false
```

## Command Line Override

Control validation via `CPD_CHECK_IMAGES` environment variable:

```bash
# Disable validation
export CPD_CHECK_IMAGES=false

# Enable with default settings
export CPD_CHECK_IMAGES=true

# Validate all images (no sampling)
export CPD_CHECK_IMAGES=all

# Validate specific number per cartridge
export CPD_CHECK_IMAGES=5
```

## Implementation Details

1. **Cartridge Detection**: Identifies cartridges with `state: installed`
2. **Name Mapping**: Maps deployer cartridge names to olm_utils names
3. **CASE File Reading**: Reads image lists directly from CASE CSV files
4. **Image Extraction**: Extracts only `cp.icr.io` images (entitled registry)
5. **Validation**: Tests each image using `skopeo inspect` with entitlement key
6. **Reporting**: Provides clear success/failure messages with resolution steps

## Benefits

- ✅ Catches authorization issues before deployment starts
- ✅ Saves time by failing fast
- ✅ Provides actionable error messages
- ✅ Scales automatically with deployment size
- ✅ Works without requiring cpd-cli container runtime
- ✅ Reads CASE files directly via Ansible playbooks

## Troubleshooting

### No images found for validation
- Ensure cartridges have `state: installed` in configuration
- Check that CASE files exist in `cpd-cli-workspace/olm-utils-workspace/work/offline/{version}/.ibm-pak/data/cases/`

### All images fail validation
- Verify entitlement key is valid: `echo $CP_ENTITLEMENT_KEY`
- Check entitlement at: https://myibm.ibm.com/products-services/containerlibrary
- Ensure key includes permissions for required components

### Validation takes too long
- Reduce `sample_size` (e.g., from 3 to 1)
- Consider disabling for development environments