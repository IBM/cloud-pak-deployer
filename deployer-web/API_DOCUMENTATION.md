# Cloud Pak Deployer Web API Documentation

This document describes all REST API endpoints available in the Cloud Pak Deployer web application (`webapp.py`).

## Base URL
- **Local Development**: `http://localhost:32080`
- **OpenShift**: Depends on route configuration

## API Version
All endpoints are prefixed with `/api/v1/`

---

## Endpoints

### 1. Root Endpoint

#### `GET /`
Serves the main web application interface.

**Response**: HTML page (index.html)

---

### 2. Mirror Images

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

### 3. Deploy Cloud Pak

#### `POST /api/v1/deploy`
Starts the Cloud Pak deployment process. Behavior differs based on context (local vs OpenShift).

**Request Body**:
```json
{
  "envId": "string",
  "oc_login_command": "string",
  "entitlementKey": "string",
  "adminPassword": "string (optional)"
}
```

**Response**: 
- Depends on deployment context (local or OpenShift)
- Returns result from `deploy_local()` or `deploy_openshift()`

**Notes**:
- Context is determined by `CPD_CONTEXT` environment variable
- For local deployments, uses `deploy_local()`
- For OpenShift deployments, uses `deploy_openshift()`

---

### 4. Download Logs

#### `POST /api/v1/download-log`
Downloads deployer logs as a file.

**Request Body**:
```json
{
  "deployerLog": "deployer-log | all-logs"
}
```

**Response**:
- For `"deployer-log"`: Returns `cloud-pak-deployer.log` file
- For `"all-logs"`: Returns `cloud-pak-deployer-logs.tar.gz` archive

**Error Responses**:
- `400 Bad Request` - Missing deployerLog field or invalid value

**Notes**:
- Behavior differs based on context (local vs OpenShift)
- Files are temporarily stored in `/tmp/`

---

### 5. OpenShift Login

#### `POST /api/v1/oc-login`
Authenticates to an OpenShift cluster using the provided `oc login` command.

**Request Body**:
```json
{
  "oc_login_command": "string"
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

**Error Response** (`code: non-zero`):
```json
{
  "code": 1,
  "error": "error message"
}
```

**Error Responses**:
- `400 Bad Request` - Invalid command format (must start with `oc login`)

**Notes**:
- Command must match pattern: `oc login ...`
- Executes the command in a subprocess

---

### 6. Check OpenShift Connection

#### `GET /api/v1/oc-check-connection`
Checks the current OpenShift connection status and retrieves cluster information.

**Response**:
```json
{
  "connected": true,
  "user": "string",
  "server": "string",
  "cluster_version": "string",
  "kubernetes_version": "string",
  "error": ""
}
```

**Success Response**:
- `connected: true` - Successfully connected to OpenShift
- `user` - Current logged-in user
- `server` - OpenShift server URL
- `cluster_version` - OpenShift version
- `kubernetes_version` - Kubernetes version

**Error Response**:
```json
{
  "connected": false,
  "user": "",
  "server": "",
  "cluster_version": "",
  "kubernetes_version": "",
  "error": "error message"
}
```

**Notes**:
- Executes `oc whoami`, `oc whoami --show-server`, and `oc version -o json`
- Returns partial information if some commands fail

---

### 7. Get Deployer Status

#### `GET /api/v1/deployer-status`
Retrieves the current status of the Cloud Pak Deployer.

**Response**: 
- Depends on deployment context (local or OpenShift)
- Returns detailed status information including:
  - Deployment state
  - Progress information
  - Pod status (for OpenShift)
  - Log file paths

**Notes**:
- For local deployments, uses `get_deployer_status_local()`
- For OpenShift deployments, uses `get_deployer_status_openshift()`
- Response structure varies based on context

---

### 8. Delete Deployer Job

#### `DELETE /api/v1/delete-deployer-job`
Deletes the Cloud Pak Deployer job and related pods in OpenShift.

**Response**:
```json
{
  "success": true,
  "message": "Cloud Pak Deployer job and related pods deleted successfully"
}
```

**Error Responses**:
- `400 Bad Request` - Operation only available for OpenShift deployments
```json
{
  "success": false,
  "message": "Delete operation is only available for OpenShift deployments"
}
```

- `500 Internal Server Error` - Error during deletion
```json
{
  "success": false,
  "message": "Error deleting job: <error details>"
}
```

**Notes**:
- Only available when running in OpenShift context
- Executes `oc delete job cloud-pak-deployer --ignore-not-found=true`

---

### 9. Read Configuration

#### `GET /api/v1/configuration`
Retrieves the current Cloud Pak Deployer configuration.

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

**Notes**:
- Loads configuration from file (local) or ConfigMap (OpenShift)
- If no existing configuration, loads default base configurations
- Supports both CP4D and CP4I configurations

---

### 10. Update Configuration

#### `PUT /api/v1/configuration`
Updates the Cloud Pak Deployer configuration.

**Request Body**:
```json
{
  "configuration": {
    "global_config": {},
    "openshift": {},
    "cp4d": {},
    "cp4i": {}
  }
}
```

**Response**: 
- Depends on deployment context
- Returns result from `update_configuration_file()` or `update_configuration_openshift()`

**Notes**:
- For local deployments, writes to configuration file
- For OpenShift deployments, updates ConfigMap
- Configuration is formatted as YAML before storage

---

### 11. Format Configuration

#### `POST /api/v1/format-configuration`
Formats the provided configuration into proper YAML structure.

**Request Body**:
```json
{
  "global_config": {},
  "openshift": {},
  "cp4d": {},
  "cp4i": {}
}
```

**Response**:
```json
{
  "code": 0,
  "message": "",
  "data": {
    "formatted_yaml": "string"
  }
}
```

**Notes**:
- Converts configuration objects to properly formatted YAML
- Sorts CP4D configuration keys by priority
- Used for preview/validation before saving

---

### 12. Get Logs

#### `GET /api/v1/logs`
Retrieves the current deployer log content.

**Response**:
```json
{
  "logs": "string"
}
```

**Notes**:
- Returns `"waiting"` if log file doesn't exist yet
- Reads from `{STATUS_DIR}/log/cloud-pak-deployer.log`
- Returns full log content as string

---

### 13. Get Environment Variables

#### `GET /api/v1/environment-variable`
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