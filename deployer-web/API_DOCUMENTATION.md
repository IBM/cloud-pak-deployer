# Cloud Pak Deployer Web API Documentation

This document describes all REST API endpoints available in the Cloud Pak Deployer web application (`webapp.py`).

## Base URL
- **Local Development**: `http://localhost:32080`
- **OpenShift**: Depends on route configuration

## API Version
All endpoints are prefixed with `/api/v1/`

## Interactive API Documentation

The API provides interactive documentation through Swagger UI and ReDoc:

### Swagger UI
- **URL**: `/api/docs`
- **Description**: Interactive API documentation with the ability to test endpoints directly from the browser
- **Features**:
  - Browse all available endpoints grouped by category
  - View request/response schemas
  - Execute API calls with sample data
  - See detailed parameter descriptions

### ReDoc
- **URL**: `/api/redoc`
- **Description**: Alternative API documentation with a clean, responsive design
- **Features**:
  - Three-panel layout for easy navigation
  - Detailed schema documentation
  - Code samples
  - Search functionality

**Example URLs**:
- Local: `http://localhost:32080/api/docs`
- Local: `http://localhost:32080/api/redoc`

---

## Table of Contents

- [API Groups](#api-groups)
- [Endpoints](#endpoints)
  - [Deployer](#deployer)
    - [1. Mirror Images](#1-mirror-images)
    - [2. Deploy Cloud Pak](#2-deploy-cloud-pak)
    - [3. Download Logs](#3-download-logs)
    - [4. Get Deployer Status](#4-get-deployer-status)
    - [5. Delete Deployer Job](#5-delete-deployer-job)
  - [OpenShift](#openshift)
    - [6. OpenShift Login](#6-openshift-login)
    - [7. Check OpenShift Connection](#7-check-openshift-connection)
  - [Configuration](#configuration)
    - [8. Read Configuration](#8-read-configuration)
    - [9. Update Configuration](#9-update-configuration)
    - [10. Format Configuration](#10-format-configuration)
    - [11. Get Environment Variables](#11-get-environment-variables)
- [Environment Variables](#environment-variables)
- [Error Handling](#error-handling)
- [Authentication](#authentication)
- [Logging](#logging)
- [Notes](#notes)

---

## API Groups

The API endpoints are organized into the following groups:

- **Deployer**: Endpoints for managing the Cloud Pak Deployer lifecycle (deploy, download logs, delete job, status)
- **OpenShift**: Endpoints for OpenShift cluster authentication and connection management
- **Configuration**: Endpoints for managing Cloud Pak Deployer configurations

---

## Endpoints

The API endpoints are organized into three main groups:

1. **Deployer** - Endpoints for deploying and managing Cloud Pak deployments
2. **OpenShift** - Endpoints for OpenShift cluster authentication and connection management
3. **Configuration** - Endpoints for managing deployer configuration

---

## Deployer

### 1. Mirror Images

#### `POST /api/v1/mirror`
Initiates the mirroring process for Cloud Pak images to a private registry.

**Request Body**:
```json
{
  "envId": "string",
  "entitlementKey": "string",
  "registry": {
    "portable": "boolean",
    "registryHostname": "string",
    "registryPort": "string",
    "registryNS": "string",
    "registryUser": "string",
    "registryPassword": "string"
  }
}
```

**Response**: 
- Status: `200 OK`
- Body: `"running"`

**Error Responses**:
- `400 Bad Request` - Missing required fields (envId, entitlementKey, or registry)

---

### 2. Deploy Cloud Pak

#### `POST /api/v1/deploy`

**Group**: `Deployer`

**Summary**: Deploy Cloud Pak

**Description**:
Initiates the Cloud Pak deployment process. This endpoint starts the deployment of Cloud Pak for Data and related components.

The behavior differs based on the deployment context:
- **Local context**: Starts a local deployment process using `cp-deploy.sh` script
- **OpenShift context**: Creates a Kubernetes Job in the deployer namespace to run the deployment

**Prerequisites**:
- Valid IBM entitlement key for accessing Cloud Pak images
- OpenShift cluster login command (for OpenShift deployments)
- Configuration files must be present in the CONFIG_DIR

**Deployment Process**:
1. Validates the configuration files
2. Prepares the deployment environment
3. Provisions infrastructure (if required)
4. Installs Cloud Pak components
5. Configures Cloud Pak settings
6. Deploys additional assets
7. Runs smoke tests

**Request Schema**:

```json
{
  "type": "object",
  "properties": {
    "envId": {
      "type": "string",
      "description": "Environment identifier for the deployment"
    },
    "oc_login_command": {
      "type": "string",
      "description": "OpenShift login command (e.g., 'oc login --token=... --server=...')"
    },
    "entitlementKey": {
      "type": "string",
      "description": "IBM entitlement key for accessing Cloud Pak container images"
    },
    "adminPassword": {
      "type": "string",
      "description": "Optional admin password for Cloud Pak for Data",
      "nullable": true
    }
  },
  "required": ["envId", "oc_login_command", "entitlementKey"]
}
```

**Request Example**:
```json
{
  "envId": "pluto-01",
  "oc_login_command": "oc login --token=sha256~abc123... --server=https://api.pluto.example.com:6443",
  "entitlementKey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "adminPassword": "MySecurePassword123!"
}
```

**Response Schema**:

```json
{
  "type": "object",
  "properties": {
    "status": {
      "type": "string",
      "description": "Status of the deployment initiation",
      "enum": ["running", "started", "error"]
    },
    "message": {
      "type": "string",
      "description": "Additional message or error details",
      "nullable": true
    },
    "job_name": {
      "type": "string",
      "description": "Name of the deployer job (OpenShift context only)",
      "nullable": true
    }
  },
  "required": ["status"]
}
```

**Responses**:

**200 OK - Local Deployment Started**:
```json
{
  "status": "running",
  "message": "Deployment started successfully",
  "job_name": null
}
```

**200 OK - OpenShift Deployment Started**:
```json
{
  "status": "started",
  "message": "Cloud Pak Deployer job created successfully",
  "job_name": "cloud-pak-deployer"
}
```

**400 Bad Request - Invalid Request**:
```json
{
  "detail": [
    {
      "loc": ["body", "entitlementKey"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

**500 Internal Server Error - Deployment Failed to Start**:
```json
{
  "status": "error",
  "message": "Failed to create deployer job: error details here"
}
```

**HTTP Status Codes**:
- `200 OK` - Deployment initiated successfully
- `400 Bad Request` - Invalid request parameters
- `500 Internal Server Error` - Failed to start deployment

**Monitoring**:
Use the `/api/v1/deployer-status` endpoint to monitor deployment progress and retrieve access credentials after successful completion.

**Important Notes**:
- This is an **asynchronous operation** - the endpoint returns immediately after starting the deployment
- The actual deployment process runs in the background
- Use the `deployer-status` endpoint to track progress
- Context is determined by `CPD_CONTEXT` environment variable
- For local deployments, uses `deploy_local()` function
- For OpenShift deployments, uses `deploy_openshift()` function and creates a Kubernetes Job

**Use Cases**:
1. **Initial deployment**: Deploy Cloud Pak for Data to a new OpenShift cluster
2. **Component installation**: Install additional Cloud Pak components or cartridges
3. **Configuration updates**: Apply configuration changes to existing deployments
4. **Automated deployments**: Integrate with CI/CD pipelines for automated Cloud Pak deployments

---

### 3. Download Logs

#### `POST /api/v1/download-log`
Downloads Cloud Pak Deployer logs as a file.

**Tags**: `Deployer`

**Description**:
This endpoint allows you to retrieve deployment logs for troubleshooting and monitoring purposes. The behavior differs based on the deployment context:

- **Local context**: Copies logs from the STATUS_DIR/log directory
- **OpenShift context**: Retrieves logs from the cloud-pak-deployer-debug pod

**Request Body**:
```json
{
  "deployerLog": "deployer-log | all-logs"
}
```

**Parameters**:
- `deployerLog` (required): Type of logs to download
  - `"deployer-log"`: Downloads only the main deployer log file
  - `"all-logs"`: Downloads a compressed archive containing all deployment logs

**Response**:
- For `"deployer-log"`: Returns `cloud-pak-deployer.log` file (text/plain)
- For `"all-logs"`: Returns `cloud-pak-deployer-logs.tar.gz` archive (application/gzip)

**Error Responses**:
- `400 Bad Request` - Missing deployerLog field or invalid value

**Use Cases**:
- Troubleshooting deployment failures
- Monitoring deployment progress offline
- Sharing logs with support teams
- Archiving deployment records

**Notes**:
- Logs are temporarily stored in `/tmp/` before being returned to the client
- Behavior differs based on context (local vs OpenShift)

---

### 4. Get Deployer Status

#### `GET /api/v1/deployer-status`

**Group**: `Deployer`

**Summary**: Get deployer status

**Description**:
Retrieves the current status of the Cloud Pak Deployer, providing real-time information about the deployment process.

This endpoint monitors the deployment lifecycle and returns comprehensive status information including:
- Whether the deployer is currently active
- Current deployment stage and progress percentage
- Last completed step description
- Completion status (successful, failed, or in progress)
- Cloud Pak access credentials (available after successful deployment)
- Image mirroring progress (during mirror operations)

The behavior differs based on the deployment context:
- **Local context**: Checks for running `cp-deploy.sh` processes using `psutil`
- **OpenShift context**: Queries deployer job, pods, and debug pods using `oc` CLI commands

**Request**: No request body required (GET request)

**Response Schema**:

```json
{
  "type": "object",
  "properties": {
    "deployer_active": {
      "type": "boolean",
      "description": "Indicates whether the Cloud Pak Deployer is currently running"
    },
    "deployer_stage": {
      "type": "string",
      "description": "Current deployment stage",
      "nullable": true
    },
    "last_step": {
      "type": "string",
      "description": "Description of the last completed step",
      "nullable": true
    },
    "percentage_completed": {
      "type": "integer",
      "description": "Percentage of deployment completion (0-100)",
      "minimum": 0,
      "maximum": 100,
      "nullable": true
    },
    "completion_state": {
      "type": "string",
      "description": "Final state of deployment ('Successful', 'Failed', or null if still running)",
      "nullable": true
    },
    "mirror_current_image": {
      "type": "string",
      "description": "Current image being mirrored (only during mirror operations)",
      "nullable": true
    },
    "mirror_number_images": {
      "type": "integer",
      "description": "Total number of images to mirror (only during mirror operations)",
      "minimum": 0,
      "nullable": true
    },
    "service_state": {
      "type": "string",
      "description": "State of Cloud Pak services",
      "nullable": true
    },
    "cp4d_url": {
      "type": "string",
      "description": "URL of the Cloud Pak for Data instance (available after successful deployment)",
      "nullable": true
    },
    "cp4d_user": {
      "type": "string",
      "description": "Admin username for Cloud Pak for Data (available after successful deployment)",
      "nullable": true
    },
    "cp4d_password": {
      "type": "string",
      "description": "Admin password for Cloud Pak for Data (available after successful deployment)",
      "nullable": true
    }
  },
  "required": ["deployer_active"]
}
```

**Deployment Stages**:

The `deployer_stage` field can contain one of the following values:

1. **`validate`** - Validating configuration files and prerequisites
2. **`prepare`** - Preparing the deployment environment
3. **`provision-infra`** - Provisioning infrastructure resources
4. **`configure-infra`** - Configuring infrastructure components
5. **`install-cloud-pak`** - Installing Cloud Pak components
6. **`configure-cloud-pak`** - Configuring Cloud Pak settings
7. **`deploy-assets`** - Deploying additional assets and configurations
8. **`smoke-tests`** - Running smoke tests to verify deployment

**Responses**:

**200 OK - Deployment In Progress**:
```json
{
  "deployer_active": true,
  "deployer_stage": "install-cloud-pak",
  "last_step": "Installing Cloud Pak for Data cartridges",
  "percentage_completed": 65,
  "completion_state": null,
  "mirror_current_image": null,
  "mirror_number_images": null,
  "service_state": "installing",
  "cp4d_url": null,
  "cp4d_user": null,
  "cp4d_password": null
}
```

**Field Descriptions**:
- `deployer_active` (boolean): `true` - Deployment is currently running
- `deployer_stage` (string): Current stage of deployment
- `last_step` (string): Description of the most recent completed step
- `percentage_completed` (integer): Progress percentage (65% complete)
- `completion_state` (null): Not yet completed
- `service_state` (string): Services are being installed
- All credential fields are `null` until deployment completes

**200 OK - Deployment Completed Successfully**:
```json
{
  "deployer_active": false,
  "deployer_stage": "smoke-tests",
  "last_step": "All smoke tests completed successfully",
  "percentage_completed": 100,
  "completion_state": "Successful",
  "mirror_current_image": null,
  "mirror_number_images": null,
  "service_state": "ready",
  "cp4d_url": "https://cpd-cpd-instance.apps.pluto.example.com",
  "cp4d_user": "admin",
  "cp4d_password": "password"
}
```

**Field Descriptions**:
- `deployer_active` (boolean): `false` - Deployment has completed
- `deployer_stage` (string): Final stage completed
- `last_step` (string): Final step description
- `percentage_completed` (integer): 100% complete
- `completion_state` (string): "Successful" - Deployment succeeded
- `service_state` (string): "ready" - Services are ready to use
- `cp4d_url` (string): URL to access Cloud Pak for Data
- `cp4d_user` (string): Admin username for login
- `cp4d_password` (string): Admin password for login

**200 OK - Deployment Failed**:
```json
{
  "deployer_active": false,
  "deployer_stage": "provision-infra",
  "last_step": "Failed to provision infrastructure",
  "percentage_completed": 25,
  "completion_state": "Failed",
  "mirror_current_image": null,
  "mirror_number_images": null,
  "service_state": null,
  "cp4d_url": null,
  "cp4d_user": null,
  "cp4d_password": null
}
```

**Field Descriptions**:
- `deployer_active` (boolean): `false` - Deployment has stopped
- `deployer_stage` (string): Stage where failure occurred
- `last_step` (string): Description of the failure
- `percentage_completed` (integer): Progress at time of failure (25%)
- `completion_state` (string): "Failed" - Deployment failed
- All other fields are `null` as deployment did not complete

**200 OK - Mirror Operation In Progress**:
```json
{
  "deployer_active": true,
  "deployer_stage": "mirror",
  "last_step": "Mirroring Cloud Pak images to private registry",
  "percentage_completed": 45,
  "completion_state": null,
  "mirror_current_image": "icr.io/cpopen/cpd/zen-core:4.8.0",
  "mirror_number_images": 150,
  "service_state": null,
  "cp4d_url": null,
  "cp4d_user": null,
  "cp4d_password": null
}
```

**Field Descriptions**:
- `deployer_active` (boolean): `true` - Mirror operation is running
- `mirror_current_image` (string): Image currently being mirrored
- `mirror_number_images` (integer): Total number of images to mirror
- Other fields track overall progress

**200 OK - No Deployment Active**:
```json
{
  "deployer_active": false
}
```

**Field Descriptions**:
- `deployer_active` (boolean): `false` - No deployment is currently running
- All other fields are absent when no deployment has been started

**HTTP Status Codes**:
- `200 OK` - Request processed successfully (always returned)

**Use Cases**:

1. **Real-time Monitoring**: Poll this endpoint to display deployment progress in a UI
2. **Progress Tracking**: Show percentage completion and current stage to users
3. **Credential Retrieval**: Obtain Cloud Pak access credentials after successful deployment
4. **Failure Detection**: Identify when and where a deployment has failed
5. **Mirror Progress**: Track image mirroring operations
6. **Automation**: Trigger post-deployment actions when `completion_state` is "Successful"

**Implementation Details**:

**Local Context**:
- Uses `psutil` to check for running `cp-deploy.sh` processes
- Reads deployment state from `{STATUS_DIR}/state/deployer-state.out`
- Parses YAML state file for detailed status information

**OpenShift Context**:
- Checks for `cloud-pak-deployer-start` pods (initial startup phase)
- Queries `cloud-pak-deployer` job status and conditions
- Checks `cloud-pak-deployer-debug` pods for detailed state
- Copies state file from debug pod using `oc cp` command
- Parses state file for detailed deployment information

**State File Fields**:

The endpoint extracts the following fields from the deployer state file:
- `deployer_stage`: Current deployment stage
- `last_step`: Last completed step description
- `percentage_completed`: Progress percentage
- `completion_state`: Final completion status
- `mirror_current_image`: Current image being mirrored
- `mirror_number_images`: Total images to mirror
- `service_state`: Cloud Pak service state
- `cp4d_url`: Cloud Pak for Data URL
- `cp4d_user`: Admin username
- `cp4d_password`: Admin password

**Polling Recommendations**:

For UI implementations, recommended polling intervals:
- **Active deployment**: Poll every 5-10 seconds
- **No active deployment**: Poll every 30-60 seconds or disable polling
- **After completion**: Stop polling or reduce to every 60+ seconds

**Notes**:
- Always returns HTTP 200 OK; check `deployer_active` to determine if deployment is running
- Response fields are dynamic; only `deployer_active` is always present
- Credential fields (`cp4d_url`, `cp4d_user`, `cp4d_password`) are only populated after successful deployment
- Mirror-related fields are only populated during image mirroring operations
- The `oc` CLI must be installed and configured for OpenShift context
- State file may not exist initially; endpoint handles missing file gracefully
- For OpenShift deployments, requires access to the deployer namespace

---

### 5. Delete Deployer Job

#### `DELETE /api/v1/delete-deployer-job`

**Group**: `Deployer`

**Summary**: Check OpenShift connection status

**Description**:
Checks the current OpenShift connection status and retrieves cluster information.

This endpoint verifies if the user is currently logged in to an OpenShift cluster and
retrieves detailed information about the cluster including:
- Current logged-in user
- OpenShift server URL
- OpenShift cluster version
- Kubernetes version

**No authentication required** - Uses the current `oc` CLI session.

**Request**: No request body required (GET request)

**Response Schema**:

```json
{
  "type": "object",
  "properties": {
    "connected": {
      "type": "boolean",
      "description": "Indicates whether the user is currently connected to an OpenShift cluster"
    },
    "user": {
      "type": "string",
      "description": "The username of the currently logged-in user"
    },
    "server": {
      "type": "string",
      "description": "The OpenShift API server URL"
    },
    "cluster_version": {
      "type": "string",
      "description": "The OpenShift cluster version"
    },
    "kubernetes_version": {
      "type": "string",
      "description": "The Kubernetes version running on the cluster"
    },
    "error": {
      "type": "string",
      "description": "Error message if connection failed, empty string if successful"
    }
  },
  "required": ["connected", "user", "server", "cluster_version", "kubernetes_version", "error"]
}
```

**Responses**:

**200 OK - Success Response (Connected)**:
```json
{
  "connected": true,
  "user": "system:admin",
  "server": "https://api.cluster.example.com:6443",
  "cluster_version": "4.12.0",
  "kubernetes_version": "v1.25.4+a34b9e9",
  "error": ""
}
```

**Field Descriptions**:
- `connected` (boolean): `true` - Successfully connected to OpenShift
- `user` (string): Current logged-in username (e.g., "system:admin", "kube:admin", "developer")
- `server` (string): OpenShift API server URL with port
- `cluster_version` (string): OpenShift cluster version (e.g., "4.12.0", "4.14.3")
- `kubernetes_version` (string): Kubernetes version with build info (e.g., "v1.25.4+a34b9e9")
- `error` (string): Empty string when successfully connected

**200 OK - Error Response (Not Connected)**:
```json
{
  "connected": false,
  "user": "",
  "server": "",
  "cluster_version": "",
  "kubernetes_version": "",
  "error": "Not logged in to OpenShift cluster"
}
```

**Field Descriptions**:
- `connected` (boolean): `false` - Not connected to OpenShift
- `user` (string): Empty string
- `server` (string): Empty string
- `cluster_version` (string): Empty string
- `kubernetes_version` (string): Empty string
- `error` (string): Error message describing why connection failed

**Example Responses**:

**Example 1: Successfully Connected (Admin User)**
```json
{
  "connected": true,
  "user": "kube:admin",
  "server": "https://api.ocp-cluster.example.com:6443",
  "cluster_version": "4.14.3",
  "kubernetes_version": "v1.27.6+f67aeb3",
  "error": ""
}
```

**Example 2: Successfully Connected (Regular User)**
```json
{
  "connected": true,
  "user": "developer",
  "server": "https://api.openshift-prod.company.com:6443",
  "cluster_version": "4.12.45",
  "kubernetes_version": "v1.25.16+9ce3e04",
  "error": ""
}
```

**Example 3: Not Logged In**
```json
{
  "connected": false,
  "user": "",
  "server": "",
  "cluster_version": "",
  "kubernetes_version": "",
  "error": "Not logged in to OpenShift cluster"
}
```

**Example 4: Partial Information (Version Retrieval Failed)**
```json
{
  "connected": true,
  "user": "system:serviceaccount:default:deployer",
  "server": "https://api.cluster.local:6443",
  "cluster_version": "",
  "kubernetes_version": "",
  "error": ""
}
```

**HTTP Status Codes**:
- `200 OK` - Request processed successfully (check `connected` field for connection status)

**Use Cases**:
- Verify login status before performing operations
- Display cluster information in the UI
- Validate cluster connectivity
- Check OpenShift and Kubernetes versions for compatibility
- Determine if re-authentication is needed

**Implementation Details**:
The endpoint executes the following commands:
1. `oc whoami` - Retrieves the current logged-in user
2. `oc whoami --show-server` - Retrieves the OpenShift server URL
3. `oc version -o json` - Retrieves version information

**Notes**:
- Returns partial information if some commands fail (e.g., version info may be missing)
- The `oc` CLI must be installed and available in the system PATH
- Does not require explicit authentication - uses existing `oc` CLI session
- If not logged in, returns `connected: false` with an error message
- Always returns HTTP 200 OK; check the `connected` field to determine actual connection status
- Version information may be empty if the `oc version` command fails (e.g., insufficient permissions)

**Summary**: Delete deployer job

**Description**:
Deletes the Cloud Pak Deployer job and related pods in OpenShift.

This endpoint removes the deployer job from the OpenShift cluster, which will also terminate any associated pods. This is useful for:

- **Cleaning up after deployment**: Remove the deployer job after successful completion
- **Stopping failed deployments**: Terminate a deployment that has failed or is stuck
- **Restarting deployments**: Delete the existing job before starting a new deployment
- **Resource management**: Free up cluster resources by removing completed jobs

**Important Notes**:
- This operation is **only available for OpenShift deployments** (not local context)
- The job deletion is idempotent - it will not fail if the job doesn't exist
- Deleting the job will terminate any running deployment process
- This does **not** delete the deployed Cloud Pak instances, only the deployer job itself
- Configuration files and status information are preserved

**Prerequisites**:
- Must be running in OpenShift context (CPD_CONTEXT=openshift)
- User must have permissions to delete jobs in the deployer namespace
- The `oc` CLI must be installed and configured

**Request**: No request body required (DELETE request)

**Response Schema**:

```json
{
  "type": "object",
  "properties": {
    "success": {
      "type": "boolean",
      "description": "Indicates whether the deletion was successful"
    },
    "message": {
      "type": "string",
      "description": "Detailed message about the deletion result"
    }
  },
  "required": ["success", "message"]
}
```

**Responses**:

**200 OK - Job Deleted Successfully**:
```json
{
  "success": true,
  "message": "Cloud Pak Deployer job and related pods deleted successfully"
}
```

**Field Descriptions**:
- `success` (boolean): `true` - Deletion completed successfully
- `message` (string): Confirmation message

**400 Bad Request - Not Available in Local Context**:
```json
{
  "success": false,
  "message": "Delete operation is only available for OpenShift deployments"
}
```

**Field Descriptions**:
- `success` (boolean): `false` - Operation not available
- `message` (string): Explains that this operation requires OpenShift context

**500 Internal Server Error - Deletion Failed**:
```json
{
  "success": false,
  "message": "Error deleting job: job.batch \"cloud-pak-deployer\" deletion failed"
}
```

**Field Descriptions**:
- `success` (boolean): `false` - Deletion failed
- `message` (string): Error details from the deletion attempt

**HTTP Status Codes**:
- `200 OK` - Job deleted successfully (or job didn't exist)
- `400 Bad Request` - Operation not available (local context)
- `500 Internal Server Error` - Error during deletion

**Use Cases**:

1. **Post-deployment cleanup**: After a successful deployment, remove the job to clean up resources
   ```bash
   curl -X DELETE http://localhost:5000/api/v1/delete-deployer-job
   ```

2. **Error recovery**: If a deployment fails, delete the job before attempting a new deployment
   ```bash
   # Delete failed job
   curl -X DELETE http://localhost:5000/api/v1/delete-deployer-job
   # Start new deployment
   curl -X POST http://localhost:5000/api/v1/deploy -d '...'
   ```

3. **Deployment restart**: Delete the existing job to start a fresh deployment with updated configuration
   ```bash
   # Update configuration first
   curl -X PUT http://localhost:5000/api/v1/configuration -d '...'
   # Delete old job
   curl -X DELETE http://localhost:5000/api/v1/delete-deployer-job
   # Start new deployment
   curl -X POST http://localhost:5000/api/v1/deploy -d '...'
   ```

4. **Resource optimization**: Remove completed jobs to free up cluster resources
   ```bash
   curl -X DELETE http://localhost:5000/api/v1/delete-deployer-job
   ```

**What Gets Deleted**:
- The `cloud-pak-deployer` Kubernetes Job in the deployer namespace
- All pods created by the job (automatically cleaned up by Kubernetes)

**What Is Preserved**:
- Deployed Cloud Pak instances and their resources (namespaces, pods, services, etc.)
- Configuration files stored in ConfigMaps
- Status information and logs (if already retrieved)
- OpenShift cluster and infrastructure resources
- Persistent volumes and data

**Implementation Details**:
- Executes: `oc delete job cloud-pak-deployer --ignore-not-found=true -n=<deployer-namespace>`
- The `--ignore-not-found=true` flag ensures idempotent behavior
- Job deletion triggers automatic cleanup of associated pods
- Returns success even if the job doesn't exist

**Notes**:
- Only available when running in OpenShift context (`CPD_CONTEXT=openshift`)
- Safe to call multiple times (idempotent operation)
- Does not affect deployed Cloud Pak instances
- Useful for cleanup and troubleshooting workflows

---

## OpenShift

### 6. OpenShift Login

#### `POST /api/v1/oc-login`

**Group**: `OpenShift`

**Summary**: Login to OpenShift cluster

**Description**:
Authenticates to an OpenShift cluster using the provided `oc login` command.

The command must be a valid `oc login` command with all necessary parameters such as:
- Server URL
- Token or username/password
- Optional flags (--insecure-skip-tls-verify, etc.)

**Request Body**:
```json
{
  "oc_login_command": "string"
}
```

**Example Request Bodies**:
```json
{
  "oc_login_command": "oc login https://api.cluster.example.com:6443 --token=sha256~xxxxx"
}
```

```json
{
  "oc_login_command": "oc login https://api.cluster.example.com:6443 -u admin -p password --insecure-skip-tls-verify"
}
```

**Response**:
```json
{
  "code": 0,
  "error": ""
}
```

**Success Response** (`code: 0`):
- Successfully logged in to OpenShift cluster
- No error message

**Error Response** (`code: non-zero`):
```json
{
  "code": 1,
  "error": "error: The server uses a certificate signed by unknown authority"
}
```

**HTTP Status Codes**:
- `200 OK` - Request processed (check `code` field for login result)
- `400 Bad Request` - Invalid command format (must start with `oc login`)

**Use Cases**:
- Initial authentication to OpenShift cluster
- Re-authentication after token expiration
- Switching between different OpenShift clusters

**Notes**:
- Command must match pattern: `oc login ...`
- Executes the command in a subprocess
- The `oc` CLI must be installed and available in the system PATH
- Login credentials are not stored by the application

---

### 7. Check OpenShift Connection

#### `GET /api/v1/oc-check-connection`

**Group**: `OpenShift`

This endpoint monitors the deployment lifecycle and returns comprehensive status information including:
- Whether the deployer is currently active
- Current deployment stage and progress percentage
- Last completed step description
- Completion status (successful, failed, or in progress)
- Cloud Pak access credentials (available after successful deployment)
- Image mirroring progress (during mirror operations)

The behavior differs based on the deployment context:
- **Local context**: Checks for running `cp-deploy.sh` processes using `psutil`
- **OpenShift context**: Queries deployer job, pods, and debug pods using `oc` CLI commands

**Request**: No request body required (GET request)

**Response Schema**:

```json
{
  "type": "object",
  "properties": {
    "deployer_active": {
      "type": "boolean",
      "description": "Indicates whether the Cloud Pak Deployer is currently running"
    },
    "deployer_stage": {
      "type": "string",
      "description": "Current deployment stage",
      "nullable": true
    },
    "last_step": {
      "type": "string",
      "description": "Description of the last completed step",
      "nullable": true
    },
    "percentage_completed": {
      "type": "integer",
      "description": "Percentage of deployment completion (0-100)",
      "minimum": 0,
      "maximum": 100,
      "nullable": true
    },
    "completion_state": {
      "type": "string",
      "description": "Final state of deployment ('Successful', 'Failed', or null if still running)",
      "nullable": true
    },
    "mirror_current_image": {
      "type": "string",
      "description": "Current image being mirrored (only during mirror operations)",
      "nullable": true
    },
    "mirror_number_images": {
      "type": "integer",
      "description": "Total number of images to mirror (only during mirror operations)",
      "minimum": 0,
      "nullable": true
    },
    "service_state": {
      "type": "string",
      "description": "State of Cloud Pak services",
      "nullable": true
    },
    "cp4d_url": {
      "type": "string",
      "description": "URL of the Cloud Pak for Data instance (available after successful deployment)",
      "nullable": true
    },
    "cp4d_user": {
      "type": "string",
      "description": "Admin username for Cloud Pak for Data (available after successful deployment)",
      "nullable": true
    },
    "cp4d_password": {
      "type": "string",
      "description": "Admin password for Cloud Pak for Data (available after successful deployment)",
      "nullable": true
    }
  },
  "required": ["deployer_active"]
}
```

**Deployment Stages**:

The `deployer_stage` field can contain one of the following values:

1. **`validate`** - Validating configuration files and prerequisites
2. **`prepare`** - Preparing the deployment environment
3. **`provision-infra`** - Provisioning infrastructure resources
4. **`configure-infra`** - Configuring infrastructure components
5. **`install-cloud-pak`** - Installing Cloud Pak components
6. **`configure-cloud-pak`** - Configuring Cloud Pak settings
7. **`deploy-assets`** - Deploying additional assets and configurations
8. **`smoke-tests`** - Running smoke tests to verify deployment

**Responses**:

**200 OK - Deployment In Progress**:
```json
{
  "deployer_active": true,
  "deployer_stage": "install-cloud-pak",
  "last_step": "Installing Cloud Pak for Data cartridges",
  "percentage_completed": 65,
  "completion_state": null,
  "mirror_current_image": null,
  "mirror_number_images": null,
  "service_state": "installing",
  "cp4d_url": null,
  "cp4d_user": null,
  "cp4d_password": null
}
```

**Field Descriptions**:
- `deployer_active` (boolean): `true` - Deployment is currently running
- `deployer_stage` (string): Current stage of deployment
- `last_step` (string): Description of the most recent completed step
- `percentage_completed` (integer): Progress percentage (65% complete)
- `completion_state` (null): Not yet completed
- `service_state` (string): Services are being installed
- All credential fields are `null` until deployment completes

**200 OK - Deployment Completed Successfully**:
```json
{
  "deployer_active": false,
  "deployer_stage": "smoke-tests",
  "last_step": "All smoke tests completed successfully",
  "percentage_completed": 100,
  "completion_state": "Successful",
  "mirror_current_image": null,
  "mirror_number_images": null,
  "service_state": "ready",
  "cp4d_url": "https://cpd-cpd-instance.apps.pluto.example.com",
  "cp4d_user": "admin",
  "cp4d_password": "password"
}
```

**Field Descriptions**:
- `deployer_active` (boolean): `false` - Deployment has completed
- `deployer_stage` (string): Final stage completed
- `last_step` (string): Final step description
- `percentage_completed` (integer): 100% complete
- `completion_state` (string): "Successful" - Deployment succeeded
- `service_state` (string): "ready" - Services are ready to use
- `cp4d_url` (string): URL to access Cloud Pak for Data
- `cp4d_user` (string): Admin username for login
- `cp4d_password` (string): Admin password for login

**200 OK - Deployment Failed**:
```json
{
  "deployer_active": false,
  "deployer_stage": "provision-infra",
  "last_step": "Failed to provision infrastructure",
  "percentage_completed": 25,
  "completion_state": "Failed",
  "mirror_current_image": null,
  "mirror_number_images": null,
  "service_state": null,
  "cp4d_url": null,
  "cp4d_user": null,
  "cp4d_password": null
}
```

**Field Descriptions**:
- `deployer_active` (boolean): `false` - Deployment has stopped
- `deployer_stage` (string): Stage where failure occurred
- `last_step` (string): Description of the failure
- `percentage_completed` (integer): Progress at time of failure (25%)
- `completion_state` (string): "Failed" - Deployment failed
- All other fields are `null` as deployment did not complete

**200 OK - Mirror Operation In Progress**:
```json
{
  "deployer_active": true,
  "deployer_stage": "mirror",
  "last_step": "Mirroring Cloud Pak images to private registry",
  "percentage_completed": 45,
  "completion_state": null,
  "mirror_current_image": "icr.io/cpopen/cpd/zen-core:4.8.0",
  "mirror_number_images": 150,
  "service_state": null,
  "cp4d_url": null,
  "cp4d_user": null,
  "cp4d_password": null
}
```

**Field Descriptions**:
- `deployer_active` (boolean): `true` - Mirror operation is running
- `mirror_current_image` (string): Image currently being mirrored
- `mirror_number_images` (integer): Total number of images to mirror
- Other fields track overall progress

**200 OK - No Deployment Active**:
```json
{
  "deployer_active": false
}
```

**Field Descriptions**:
- `deployer_active` (boolean): `false` - No deployment is currently running
- All other fields are absent when no deployment has been started

**HTTP Status Codes**:
- `200 OK` - Request processed successfully (always returned)

**Use Cases**:

1. **Real-time Monitoring**: Poll this endpoint to display deployment progress in a UI
2. **Progress Tracking**: Show percentage completion and current stage to users
3. **Credential Retrieval**: Obtain Cloud Pak access credentials after successful deployment
4. **Failure Detection**: Identify when and where a deployment has failed
5. **Mirror Progress**: Track image mirroring operations
6. **Automation**: Trigger post-deployment actions when `completion_state` is "Successful"

**Implementation Details**:

**Local Context**:
- Uses `psutil` to check for running `cp-deploy.sh` processes
- Reads deployment state from `{STATUS_DIR}/state/deployer-state.out`
- Parses YAML state file for detailed status information

**OpenShift Context**:
- Checks for `cloud-pak-deployer-start` pods (initial startup phase)
- Queries `cloud-pak-deployer` job status and conditions
- Checks `cloud-pak-deployer-debug` pods for detailed state
- Copies state file from debug pod using `oc cp` command
- Parses state file for detailed deployment information

**State File Fields**:

The endpoint extracts the following fields from the deployer state file:
- `deployer_stage`: Current deployment stage
- `last_step`: Last completed step description
- `percentage_completed`: Progress percentage
- `completion_state`: Final completion status
- `mirror_current_image`: Current image being mirrored
- `mirror_number_images`: Total images to mirror
- `service_state`: Cloud Pak service state
- `cp4d_url`: Cloud Pak for Data URL
- `cp4d_user`: Admin username
- `cp4d_password`: Admin password

**Polling Recommendations**:

For UI implementations, recommended polling intervals:
- **Active deployment**: Poll every 5-10 seconds
- **No active deployment**: Poll every 30-60 seconds or disable polling
- **After completion**: Stop polling or reduce to every 60+ seconds

**Notes**:
- Always returns HTTP 200 OK; check `deployer_active` to determine if deployment is running
- Response fields are dynamic; only `deployer_active` is always present
- Credential fields (`cp4d_url`, `cp4d_user`, `cp4d_password`) are only populated after successful deployment
- Mirror-related fields are only populated during image mirroring operations
- The `oc` CLI must be installed and configured for OpenShift context
- State file may not exist initially; endpoint handles missing file gracefully
- For OpenShift deployments, requires access to the deployer namespace

---

## Configuration

### 8. Read Configuration

#### `GET /api/v1/configuration`

This endpoint removes the deployer job from the OpenShift cluster, which will also terminate any associated pods. This is useful for:

- **Cleaning up after deployment**: Remove the deployer job after successful completion
- **Stopping failed deployments**: Terminate a deployment that has failed or is stuck
- **Restarting deployments**: Delete the existing job before starting a new deployment
- **Resource management**: Free up cluster resources by removing completed jobs

**Important Notes**:
- This operation is **only available for OpenShift deployments** (not local context)
- The job deletion is idempotent - it will not fail if the job doesn't exist
- Deleting the job will terminate any running deployment process
- This does **not** delete the deployed Cloud Pak instances, only the deployer job itself
- Configuration files and status information are preserved

**Prerequisites**:
- Must be running in OpenShift context (CPD_CONTEXT=openshift)
- User must have permissions to delete jobs in the deployer namespace
- The `oc` CLI must be installed and configured

**Request**: No request body required (DELETE request)

**Response Schema**:

```json
{
  "type": "object",
  "properties": {
    "success": {
      "type": "boolean",
      "description": "Indicates whether the deletion was successful"
    },
    "message": {
      "type": "string",
      "description": "Detailed message about the deletion result"
    }
  },
  "required": ["success", "message"]
}
```

**Responses**:

**200 OK - Job Deleted Successfully**:
```json
{
  "success": true,
  "message": "Cloud Pak Deployer job and related pods deleted successfully"
}
```

**Field Descriptions**:
- `success` (boolean): `true` - Deletion completed successfully
- `message` (string): Confirmation message

**400 Bad Request - Not Available in Local Context**:
```json
{
  "success": false,
  "message": "Delete operation is only available for OpenShift deployments"
}
```

**Field Descriptions**:
- `success` (boolean): `false` - Operation not available
- `message` (string): Explains that this operation requires OpenShift context

**500 Internal Server Error - Deletion Failed**:
```json
{
  "success": false,
  "message": "Error deleting job: job.batch \"cloud-pak-deployer\" deletion failed"
}
```

**Field Descriptions**:
- `success` (boolean): `false` - Deletion failed
- `message` (string): Error details from the deletion attempt

**HTTP Status Codes**:
- `200 OK` - Job deleted successfully (or job didn't exist)
- `400 Bad Request` - Operation not available (local context)
- `500 Internal Server Error` - Error during deletion

**Use Cases**:

1. **Post-deployment cleanup**: After a successful deployment, remove the job to clean up resources
   ```bash
   curl -X DELETE http://localhost:5000/api/v1/delete-deployer-job
   ```

2. **Error recovery**: If a deployment fails, delete the job before attempting a new deployment
   ```bash
   # Delete failed job
   curl -X DELETE http://localhost:5000/api/v1/delete-deployer-job
   # Start new deployment
   curl -X POST http://localhost:5000/api/v1/deploy -d '...'
   ```

3. **Deployment restart**: Delete the existing job to start a fresh deployment with updated configuration
   ```bash
   # Update configuration first
   curl -X PUT http://localhost:5000/api/v1/configuration -d '...'
   # Delete old job
   curl -X DELETE http://localhost:5000/api/v1/delete-deployer-job
   # Start new deployment
   curl -X POST http://localhost:5000/api/v1/deploy -d '...'
   ```

4. **Resource optimization**: Remove completed jobs to free up cluster resources
   ```bash
   curl -X DELETE http://localhost:5000/api/v1/delete-deployer-job
   ```

**What Gets Deleted**:
- The `cloud-pak-deployer` Kubernetes Job in the deployer namespace
- All pods created by the job (automatically cleaned up by Kubernetes)

**What Is Preserved**:
- Deployed Cloud Pak instances and their resources (namespaces, pods, services, etc.)
- Configuration files stored in ConfigMaps
- Status information and logs (if already retrieved)
- OpenShift cluster and infrastructure resources
- Persistent volumes and data

**Implementation Details**:
- Executes: `oc delete job cloud-pak-deployer --ignore-not-found=true -n=<deployer-namespace>`
- The `--ignore-not-found=true` flag ensures idempotent behavior
- Job deletion triggers automatic cleanup of associated pods
- Returns success even if the job doesn't exist

**Notes**:
- Only available when running in OpenShift context (`CPD_CONTEXT=openshift`)
- Safe to call multiple times (idempotent operation)
- Does not affect deployed Cloud Pak instances
- Useful for cleanup and troubleshooting workflows

Retrieves the current Cloud Pak Deployer configuration.

**Tags**: `Configuration`

**Summary**: Get Configuration

**Description**:
Retrieves the current Cloud Pak Deployer configuration.

This endpoint loads the configuration from either a local file or an OpenShift ConfigMap,
depending on the deployment context. If no existing configuration is found, it returns
default base configurations.

**Behavior:**
- **Local context**: Reads from configuration file in CONFIG_DIR
- **OpenShift context**: Reads from ConfigMap in the deployer namespace

**Response includes:**
- `code`: 0 for success, -1 for error
- `message`: Description of the operation result
- `content`: Raw YAML representation of the configuration
- `data`: Parsed configuration objects organized by type (global_config, openshift, cp4d, cp4i)
- `metadata`: Information about configuration state and selected Cloud Pak

**Response**:
```json
{
  "code": 0,
  "message": "string",
  "content": "string",
  "data": {
    "global_config": {},
    "openshift": {},
    "cp4d": {},
    "cp4i": {}
  },
  "metadata": {
    "existing_config": true,
    "selectedCloudPak": "software-hub | cp4i"
  }
}
```

**Success Response** (`code: 0`):
- `data` - Configuration objects for global, OpenShift, and Cloud Paks
- `metadata` - Information about configuration state

**Example Response**:
```json
{
  "code": 0,
  "message": "Configuration loaded successfully",
  "content": "global_config:\n- project: cpd-instance\n  env_id: pluto-01\n...",
  "data": {
    "global_config": [
      {
        "project": "cpd-instance",
        "env_id": "pluto-01",
        "cloud_platform": "existing-ocp",
        "env_type": "development",
        "confirm_destroy": false
      }
    ],
    "openshift": [
      {
        "name": "pluto",
        "ocp_version": "4.12",
        "cluster_name": "pluto",
        "domain_name": "example.com",
        "openshift_storage": [
          {
            "storage_name": "ocs-storage",
            "storage_type": "ocs",
            "ocs_storage_label": "ocs",
            "ocs_storage_size_gb": 500
          }
        ]
      }
    ],
    "cp4d": [
      {
        "project": "cpd-instance",
        "openshift_cluster_name": "pluto",
        "cp4d_version": "4.8",
        "cartridges": [
          {
            "name": "cp-foundation",
            "license_service": {
              "state": "disabled"
            }
          },
          {
            "name": "lite",
            "version": "4.8.0",
            "size": "small"
          }
        ]
      }
    ],
    "cp4i": []
  },
  "metadata": {
    "existing_config": true,
    "selectedCloudPak": "software-hub"
  }
}
```

**Example Response (No Existing Configuration)**:
```json
{
  "code": 0,
  "message": "No existing configuration found, loaded defaults",
  "content": "",
  "data": {
    "global_config": [
      {
        "project": "sample",
        "env_id": "sample",
        "cloud_platform": "existing-ocp"
      }
    ],
    "openshift": [],
    "cp4d": [],
    "cp4i": []
  },
  "metadata": {
    "existing_config": false,
    "selectedCloudPak": "software-hub"
  }
}
```

**Notes**:
- Loads configuration from file (local) or ConfigMap (OpenShift)
- If no existing configuration, loads default base configurations
- Supports both CP4D and CP4I configurations
- The `content` field contains the raw YAML representation of the configuration
- The `data` field contains parsed configuration objects organized by type

---

### 9. Update Configuration

#### `PUT /api/v1/configuration`

**Tags**: `Configuration`

**Summary**: Update Configuration

**Description**:
Updates the Cloud Pak Deployer configuration.

This endpoint saves the provided configuration to either a local file or an OpenShift ConfigMap,
depending on the deployment context. The configuration is formatted as YAML before storage.

**Behavior:**
- **Local context**: Writes configuration to file specified in metadata.config_file_path
- **OpenShift context**: Updates ConfigMap 'cloud-pak-deployer-config' in the deployer namespace

**Request Body Requirements:**
- Must include complete configuration with `data` and `metadata` sections
- `data` should contain: global_config, openshift, cp4d, and/or cp4i arrays
- `metadata` should include: config_file_path (for local) and selectedCloudPak

**Configuration Processing:**
1. Validates and formats the configuration as YAML
2. Sorts CP4D configuration keys by priority
3. Saves to file (local) or ConfigMap (OpenShift)
4. Returns the formatted YAML configuration

**Note:** For OpenShift deployments, the ConfigMap is created if it doesn't exist.

**Request Body**:
```json
{
  "configuration": {
    "data": {
      "global_config": [
        {
          "project": "cpd-instance",
          "env_id": "pluto-01",
          "cloud_platform": "existing-ocp",
          "env_type": "development",
          "confirm_destroy": false
        }
      ],
      "openshift": [
        {
          "name": "pluto",
          "ocp_version": "4.12",
          "cluster_name": "pluto",
          "domain_name": "example.com",
          "openshift_storage": [
            {
              "storage_name": "ocs-storage",
              "storage_type": "ocs",
              "ocs_storage_label": "ocs",
              "ocs_storage_size_gb": 500
            }
          ]
        }
      ],
      "cp4d": [
        {
          "project": "cpd-instance",
          "openshift_cluster_name": "pluto",
          "cp4d_version": "4.8",
          "cartridges": [
            {
              "name": "cp-foundation",
              "license_service": {
                "state": "disabled"
              }
            },
            {
              "name": "lite",
              "version": "4.8.0",
              "size": "small"
            }
          ]
        }
      ],
      "cp4i": []
    },
    "metadata": {
      "config_file_path": "/path/to/config.yaml",
      "selectedCloudPak": "software-hub"
    }
  }
}
```

**Response**:
```json
{
  "config": "global_config:\n- project: cpd-instance\n  env_id: pluto-01\n  cloud_platform: existing-ocp\n  env_type: development\n  confirm_destroy: false\n\nopenshift:\n- name: pluto\n  ocp_version: '4.12'\n  cluster_name: pluto\n  domain_name: example.com\n  openshift_storage:\n  - storage_name: ocs-storage\n    storage_type: ocs\n    ocs_storage_label: ocs\n    ocs_storage_size_gb: 500\n\ncp4d:\n- project: cpd-instance\n  openshift_cluster_name: pluto\n  cp4d_version: '4.8'\n  cartridges:\n  - name: cp-foundation\n    license_service:\n      state: disabled\n  - name: lite\n    version: 4.8.0\n    size: small\n"
}
```

**Response**:
```json
{
  "config": "global_config:\n- project: cpd-instance\n  env_id: pluto-01\n  cloud_platform: existing-ocp\n  env_type: development\n  confirm_destroy: false\n\nopenshift:\n- name: pluto\n  ocp_version: '4.12'\n  cluster_name: pluto\n  domain_name: example.com\n  openshift_storage:\n  - storage_name: ocs-storage\n    storage_type: ocs\n    ocs_storage_label: ocs\n    ocs_storage_size_gb: 500\n\ncp4d:\n- project: cpd-instance\n  openshift_cluster_name: pluto\n  cp4d_version: '4.8'\n  cartridges:\n  - name: cp-foundation\n    license_service:\n      state: disabled\n  - name: lite\n    version: 4.8.0\n    size: small\n"
}
```

**Success Response**:
- Returns the formatted YAML configuration as a string in the `config` field
- Configuration is validated and formatted before storage

**Error Responses**:
- `400 Bad Request` - Invalid configuration format or missing required fields

**Notes**:
- For local deployments, writes to configuration file specified in `metadata.config_file_path`
- For OpenShift deployments, updates ConfigMap `cloud-pak-deployer-config` in the deployer namespace
- Configuration is formatted as YAML before storage
- CP4D configuration keys are sorted by priority during formatting
- For OpenShift context, the ConfigMap is created if it doesn't exist
- The `metadata` section must include `config_file_path` for local deployments

---

### 10. Format Configuration

#### `POST /api/v1/format-configuration`

**Tags**: `Configuration`

**Description**:
Formats the provided configuration data into a properly structured YAML string suitable for deployment. This endpoint takes configuration data organized by component type (global_config, openshift, cp4d, cp4i) and converts it into a formatted YAML string with proper structure, sorted keys, and consistent indentation.

**Request Body**:
```json
{
  "data": {
    "global_config": [
      {
        "project": "cpd-instance",
        "env_id": "pluto-01",
        "cloud_platform": "existing-ocp",
        "env_type": "development"
      }
    ],
    "openshift": [
      {
        "name": "pluto",
        "ocp_version": "4.12",
        "cluster_name": "pluto",
        "domain_name": "example.com"
      }
    ],
    "cp4d": [
      {
        "project": "cpd-instance",
        "openshift_cluster_name": "pluto",
        "cp4d_version": "4.8",
        "cartridges": [
          {
            "name": "cp-foundation",
            "license_service": {
              "state": "disabled"
            }
          },
          {
            "name": "lite",
            "version": "4.8.0",
            "size": "small"
          }
        ]
      }
    ],
    "cp4i": []
  },
  "metadata": {
    "existing_config": true,
    "selectedCloudPak": "software-hub"
  }
}
```

**Request Schema**:
- `data` (required): ConfigurationData object containing:
  - `global_config` (array): Global configuration settings
  - `openshift` (array): OpenShift cluster configuration
  - `cp4d` (array): Cloud Pak for Data configuration
  - `cp4i` (array): Cloud Pak for Integration configuration
- `metadata` (required): ConfigurationMetadata object containing:
  - `existing_config` (boolean): Whether an existing configuration was found
  - `selectedCloudPak` (string): Selected Cloud Pak ('software-hub' or 'cp4i')

**Processing Order**:
The function processes configuration sections in the following order:
1. Global configuration settings
2. OpenShift cluster configuration
3. Cloud Pak for Data configuration (if `selectedCloudPak` is 'software-hub')
4. Cloud Pak for Integration configuration (if `selectedCloudPak` is 'cp4i')

**Response**:
```json
{
  "code": 0,
  "message": "",
  "data": {
    "formatted_yaml": "---\nglobal_config:\n- project: cpd-instance\n  env_id: pluto-01\n  cloud_platform: existing-ocp\n  env_type: development\n\nopenshift:\n- name: pluto\n  ocp_version: '4.12'\n  cluster_name: pluto\n  domain_name: example.com\n\ncp4d:\n- project: cpd-instance\n  openshift_cluster_name: pluto\n  cp4d_version: '4.8'\n  cartridges:\n  - name: cp-foundation\n    license_service:\n      state: disabled\n  - name: lite\n    version: 4.8.0\n    size: small\n"
  }
}
```

**Response Schema**:
- `code` (integer): Response code (0 for success, -1 for error)
- `message` (string): Response message describing the result
- `data` (object): Contains the formatted YAML
  - `formatted_yaml` (string): The formatted YAML configuration string

**Success Response** (`code: 0`):
- Returns properly formatted YAML string in `data.formatted_yaml`
- YAML includes document separators (`---`)
- CP4D configuration keys are sorted by priority
- Consistent indentation and formatting applied

**Error Responses**:
- `400 Bad Request` - Invalid request, missing or malformed configuration data
- `500 Internal Server Error` - Error during formatting process

**Use Cases**:
1. **Preview Configuration**: View how the configuration will look before saving
2. **Validation**: Validate configuration structure and formatting
3. **Direct Deployment**: Use the formatted YAML directly in deployment files
4. **Configuration Export**: Export configuration in a standardized format

**Notes**:
- Converts configuration objects to properly formatted YAML
- Sorts CP4D configuration keys by priority for better readability
- Used for preview/validation before saving configuration
- The `selectedCloudPak` metadata field determines which Cloud Pak configuration to include
- Empty arrays are preserved in the output

---

### 11. Get Environment Variables

#### `GET /api/v1/environment-variable`

**Tags**: `Configuration`

**Summary**: Get environment variables

**Description**:
Retrieves environment configuration variables.

**Response**:
```json
{
  "CPD_WIZARD_PAGE_TITLE": "string",
  "CPD_WIZARD_MODE": "string",
  "STATUS_DIR": "string",
  "CONFIG_DIR": "string",
  "CPD_CONTEXT": "local | openshift"
}
```

**Notes**:
- Returns configuration from environment variables
- Used by frontend to adapt UI based on deployment context

---

## Environment Variables

The application uses the following environment variables:

- `CPD_CONTEXT` - Deployment context: `local` or `openshift` (default: `local`)
- `CPD_WIZARD_LOG_LEVEL` - Logging level: `DEBUG`, `INFO`, `WARNING`, `ERROR` (default: `INFO`)
- `CPD_DEPLOYER_PROJECT` - OpenShift project/namespace (default: `cloud-pak-deployer`)
- `CONFIG_DIR` - Directory for configuration files
- `STATUS_DIR` - Directory for status and log files
- `CPD_WIZARD_PAGE_TITLE` - Custom page title (default: `Cloud Pak Deployer`)
- `CPD_WIZARD_MODE` - Wizard mode configuration

---

## Error Handling

### Common HTTP Status Codes

- `200 OK` - Successful request
- `400 Bad Request` - Invalid request parameters or body
- `500 Internal Server Error` - Server-side error during processing

### Error Response Format

Most endpoints return errors in this format:
```json
{
  "code": -1,
  "error": "error message",
  "message": "detailed error description"
}
```

---

## Authentication

Currently, the API does not implement authentication. Access control should be managed at the infrastructure level (e.g., OpenShift routes, network policies).

---

## Logging

The application logs to stdout with configurable log levels. Set `CPD_WIZARD_LOG_LEVEL` environment variable to control verbosity:
- `DEBUG` - Detailed debugging information
- `INFO` - General informational messages (default)
- `WARNING` - Warning messages
- `ERROR` - Error messages only

---

## Notes

1. **Context-Aware Behavior**: Many endpoints behave differently based on the `CPD_CONTEXT` environment variable (local vs OpenShift).

2. **Asynchronous Operations**: Deployment and mirroring operations are asynchronous. Use the status endpoints to monitor progress.

3. **File Paths**: Configuration and status directories are configurable via environment variables.

4. **OpenShift Integration**: When running in OpenShift context, the application uses `oc` CLI commands for cluster operations.

5. **YAML Processing**: Configuration files are processed as YAML with support for multi-document files.