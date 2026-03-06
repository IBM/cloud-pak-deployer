# Fix for Image Validation Issue #1085

## Problem

The `skopeo inspect` command was failing with "manifest unknown" error:

```bash
skopeo inspect --creds cp:${CP_ENTITLEMENT_KEY} docker://cp.icr.io/cp/cpd/zen-metastoredb:5.0.0
FATA[0000] Error parsing image name "docker://cp.icr.io/cp/cpd/zen-metastoredb:5.0.0": reading manifest 5.0.0 in cp.icr.io/cp/cpd/zen-metastoredb: manifest unknown
```

## Root Cause

The implementation in `automation-roles/10-validation/check-images/tasks/get-sample-images.yml` was incorrectly constructing image names by:

1. **Using cartridge names directly as image names**: Cartridge name `zen` ≠ Image name `zen-metastoredb`
2. **Using `:latest` tag**: CP4D images don't have a `:latest` tag, they use specific version tags like `5.0.0`

The code was doing:
```yaml
'image': 'cp.icr.io/cp/cpd/' + item + ':latest'
```

This resulted in invalid image references like `cp.icr.io/cp/cpd/zen:latest` which don't exist.

## Solution

Replaced the hardcoded template approach with **dynamic image discovery using `cpd-cli`**:

```bash
cpd-cli manage list-images \
  --release=5.0.0 \
  --components=cpfs,cpd_platform,ws,spss \
  --inspect_source_registry=true
```

### Benefits

1. **Always up-to-date**: Gets actual images directly from IBM
2. **Version-aware**: Uses correct images for your CP4D version
3. **Component-specific**: Only checks images you're deploying
4. **Correct tags/digests**: Uses actual image references with proper tags or SHA digests

## Changes Made

### 1. Updated `get-sample-images.yml`

- Added cpd-cli availability check
- Implemented dynamic image fetching using `cpd-cli manage list-images`
- Added proper error handling when cpd-cli is not available
- Parses cpd-cli output to extract actual image references

### 2. Updated `validate-images.yml`

- Added skip logic when no images are found
- Wrapped validation in a block that only runs when images exist

## Testing

### Prerequisites

1. Install cpd-cli:
   ```bash
   # Follow instructions at:
   # https://www.ibm.com/docs/en/software-hub/5.1.x?topic=manage-list-images
   ```

2. Verify cpd-cli is available:
   ```bash
   cpd-cli version
   which cpd-cli
   ```

### Test Scenarios

#### 1. With cpd-cli installed (Normal Operation)

```bash
./cp-deploy.sh env apply --config-dir ./config
```

**Expected**: 
- cpd-cli fetches actual images
- Validation runs against real image references
- Success message shows number of images validated

#### 2. Without cpd-cli (Graceful Degradation)

```bash
# Temporarily rename cpd-cli
sudo mv /usr/local/bin/cpd-cli /usr/local/bin/cpd-cli.bak

./cp-deploy.sh env apply --config-dir ./config
```

**Expected**:
- Warning message: "cpd-cli is NOT available - validation will be skipped"
- Deployment continues without validation
- No fatal errors

#### 3. With Invalid Entitlement Key

```bash
# Set invalid key in vault
./cp-deploy.sh env apply --config-dir ./config
```

**Expected**:
- cpd-cli fetches images successfully
- skopeo validation fails with clear error message
- Deployment stops with actionable error

#### 4. Validation Disabled

```yaml
# In config
check_images:
  enabled: false
```

```bash
./cp-deploy.sh env apply --config-dir ./config
```

**Expected**:
- Validation skipped entirely
- No cpd-cli calls
- Deployment continues

## Verification Commands

### Manual Image Validation

Test the fix manually:

```bash
# 1. Get actual images using cpd-cli
cpd-cli manage list-images \
  --release=5.0.0 \
  --components=cpfs,cpd_platform \
  --inspect_source_registry=true | grep "^cp.icr.io" | head -5

# 2. Test one of the returned images with skopeo
skopeo inspect --creds cp:${CP_ENTITLEMENT_KEY} \
  docker://<image-from-step-1>
```

### Expected Output

```
# cpd-cli output (example):
cp.icr.io/cp/cpd/zen-metastoredb@sha256:abc123...
cp.icr.io/cp/cpd/zen-core-api@sha256:def456...
cp.icr.io/cp/cpd/cpd-platform-operator@sha256:ghi789...

# skopeo output (success):
{
  "Name": "cp.icr.io/cp/cpd/zen-metastoredb",
  "Digest": "sha256:abc123...",
  "RepoTags": ["5.0.0", "5.0.1"],
  ...
}
```

## Rollback

If issues occur, you can disable validation:

```yaml
global_config:
  check_images:
    enabled: false
```

Or use command line:

```bash
./cp-deploy.sh env apply --check-images=false
```

## Related Documentation

- [check-images.md](docs/src/30-reference/configuration/check-images.md) - User documentation
- [check-images-readme.md](docs/src/30-reference/configuration/check-images-readme.md) - Implementation details
- [GitHub Issue #1085](https://github.com/IBM/cloud-pak-deployer/issues/1085) - Original issue

## Notes

- The fix aligns the implementation with the documentation, which already described using cpd-cli
- cpd-cli is required for this feature to work properly
- For air-gapped environments, validation is automatically skipped
- The smart sampling strategy (default: 3 images per component) is preserved