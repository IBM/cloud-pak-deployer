from time import sleep
from typing import Any, Optional, Dict, Literal, List
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
import sys, psutil, subprocess, os, getpass, json
from shutil import copy2
from pathlib import Path
import glob, zipfile, tarfile
import logging
import yaml

# Configure the logging
logging.basicConfig(
    level=os.getenv('CPD_WIZARD_LOG_LEVEL', 'INFO'),
    format='[%(asctime)s] %(levelname)s in %(module)s: %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)

logger = logging.getLogger(__name__)

# Define tags metadata for Swagger UI ordering
tags_metadata = [
    {
        "name": "Configuration",
        "description": "Endpoints for managing Cloud Pak Deployer configurations"
    },
    {
        "name": "OpenShift",
        "description": "Endpoints for OpenShift cluster authentication and connection management"
    },
    {
        "name": "Deployer",
        "description": "Endpoints for managing the Cloud Pak Deployer lifecycle"
    }
]

# Initialize FastAPI app
app = FastAPI(
    title="Cloud Pak Deployer API",
    description="REST API for Cloud Pak Deployer",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_tags=tags_metadata
)

deployer_dir = Path(os.path.dirname(os.path.realpath(__file__))).parent
logger.info('Deployer directory: {}'.format(deployer_dir))
cp_base_config_path = os.path.join(deployer_dir,'sample-configurations/sample-dynamic/config-samples')
ocp_base_config_path = os.path.join(deployer_dir,'sample-configurations/sample-dynamic/config-samples')
running_context=str(os.getenv('CPD_CONTEXT', default='local'))
logger.info('Deployer context: {}'.format(running_context))
logger.info('Logging level (CPD_WIZARD_LOG_LEVEL): {}'.format(str(os.getenv('CPD_WIZARD_LOG_LEVEL', default='INFO'))))
deployer_project = str(os.getenv('CPD_DEPLOYER_PROJECT', default='cloud-pak-deployer'))
config_dir=str(os.getenv('CONFIG_DIR'))
status_dir=str(os.getenv('STATUS_DIR'))

# Suppress uvicorn access logs if needed
logging.getLogger("uvicorn.access").setLevel(logging.ERROR)

# Pydantic Models
class RegistryConfig(BaseModel):
    portable: bool
    registryHostname: str
    registryPort: str
    registryNS: str
    registryUser: str
    registryPassword: str

class MirrorRequest(BaseModel):
    envId: str
    entitlementKey: str
    registry: RegistryConfig

class DeployRequest(BaseModel):
    envId: str
    oc_login_command: str
    entitlementKey: str
    adminPassword: Optional[str] = None

class DeployResponse(BaseModel):
    """Response model for deploy endpoint."""
    status: str = Field(..., description="Status of the deployment initiation ('running', 'started', 'error')")
    message: Optional[str] = Field(None, description="Additional message or error details")
    job_name: Optional[str] = Field(None, description="Name of the deployer job (OpenShift context only)")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "status": "running",
                    "message": "Deployment started successfully",
                    "job_name": None
                },
                {
                    "status": "started",
                    "message": "Cloud Pak Deployer job created successfully",
                    "job_name": "cloud-pak-deployer"
                }
            ]
        }
    }

class DeleteDeployerJobResponse(BaseModel):
    """Response model for delete deployer job endpoint."""
    success: bool = Field(..., description="Indicates whether the deletion was successful")
    message: str = Field(..., description="Detailed message about the deletion result")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "success": True,
                    "message": "Cloud Pak Deployer job and related pods deleted successfully"
                },
                {
                    "success": False,
                    "message": "Delete operation is only available for OpenShift deployments"
                },
                {
                    "success": False,
                    "message": "Error deleting job: job.batch \"cloud-pak-deployer\" not found"
                }
            ]
        }
    }

class DownloadLogRequest(BaseModel):
    """Request model for downloading deployer logs."""
    deployerLog: Literal["deployer-log", "all-logs"] = Field(
        ...,
        description="Type of logs to download: 'deployer-log' for main log file only, 'all-logs' for complete log archive"
    )
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "deployerLog": "deployer-log"
                },
                {
                    "deployerLog": "all-logs"
                }
            ]
        }
    }

class OcLoginRequest(BaseModel):
    oc_login_command: str

class OcCheckConnectionResponse(BaseModel):
    """Response model for OpenShift connection check."""
    connected: bool = Field(..., description="Indicates whether the user is currently connected to an OpenShift cluster")
    user: str = Field(..., description="The username of the currently logged-in user")
    server: str = Field(..., description="The OpenShift API server URL")
    cluster_version: str = Field(..., description="The OpenShift cluster version")
    kubernetes_version: str = Field(..., description="The Kubernetes version running on the cluster")
    error: str = Field(..., description="Error message if connection failed, empty string if successful")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "connected": True,
                    "user": "kube:admin",
                    "server": "https://api.ocp-cluster.example.com:6443",
                    "cluster_version": "4.14.3",
                    "kubernetes_version": "v1.27.6+f67aeb3",
                    "error": ""
                },
                {
                    "connected": True,
                    "user": "developer",
                    "server": "https://api.openshift-prod.company.com:6443",
                    "cluster_version": "4.12.45",
                    "kubernetes_version": "v1.25.16+9ce3e04",
                    "error": ""
                },
                {
                    "connected": False,
                    "user": "",
                    "server": "",
                    "cluster_version": "",
                    "kubernetes_version": "",
                    "error": "Not logged in to OpenShift cluster"
                },
                {
                    "connected": True,
                    "user": "system:serviceaccount:default:deployer",
                    "server": "https://api.cluster.local:6443",
                    "cluster_version": "",
                    "kubernetes_version": "",
                    "error": ""
                }
            ]
        }
    }
class ServiceState(BaseModel):
    """Model for individual service state."""
    service: str = Field(..., description="Name of the service")
    state: str = Field(..., description="Current state of the service")
    progress: str = Field(..., description="Progress percentage")
    version: str = Field(..., description="Version of the service")

class DeployerStatusResponse(BaseModel):
    """Response model for deployer status."""
    deployer_active: bool = Field(..., description="Indicates whether the Cloud Pak Deployer is currently running")
    deployer_stage: Optional[str] = Field(None, description="Current deployment stage (e.g., 'validate', 'prepare', 'provision-infra', 'configure-infra', 'install-cloud-pak', 'configure-cloud-pak', 'deploy-assets', 'smoke-tests')")
    last_step: Optional[str] = Field(None, description="Description of the last completed step")
    percentage_completed: Optional[int] = Field(None, description="Percentage of deployment completion (0-100)", ge=0, le=100)
    completion_state: Optional[str] = Field(None, description="Final state of deployment ('Successful', 'Failed', or not set if still running)")
    mirror_current_image: Optional[str] = Field(None, description="Current image being mirrored (only during mirror operations)")
    mirror_number_images: Optional[int] = Field(None, description="Total number of images to mirror (only during mirror operations)", ge=0)
    service_state: Optional[List[ServiceState]] = Field(None, description="State of Cloud Pak services")
    cp4d_url: Optional[str] = Field(None, description="URL of the Cloud Pak for Data instance (available after successful deployment)")
    cp4d_user: Optional[str] = Field(None, description="Admin username for Cloud Pak for Data (available after successful deployment)")
    cp4d_password: Optional[str] = Field(None, description="Admin password for Cloud Pak for Data (available after successful deployment)")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "deployer_active": True,
                    "deployer_stage": "install-cloud-pak",
                    "last_step": "Installing Cloud Pak for Data cartridges",
                    "percentage_completed": 65,
                    "completion_state": None,
                    "mirror_current_image": None,
                    "mirror_number_images": None,
                    "service_state": [{"service": "cpd_platform", "state": "Installing", "progress": "50%", "version": "5.4.0"}],
                    "cp4d_url": None,
                    "cp4d_user": None,
                    "cp4d_password": None
                },
                {
                    "deployer_active": False,
                    "deployer_stage": "smoke-tests",
                    "last_step": "All smoke tests completed successfully",
                    "percentage_completed": 100,
                    "completion_state": "Successful",
                    "mirror_current_image": None,
                    "mirror_number_images": None,
                    "service_state": [
                        {"service": "cpd_platform", "state": "Completed", "progress": "100%", "version": "5.4.0"},
                        {"service": "watsonx_data", "state": "Completed", "progress": "100%", "version": "2.3.1"}
                    ],
                    "cp4d_url": "https://cpd-cpd-instance.apps.pluto.example.com",
                    "cp4d_user": "admin",
                    "cp4d_password": "password"
                },
                {
                    "deployer_active": False,
                    "deployer_stage": "provision-infra",
                    "last_step": "Failed to provision infrastructure",
                    "percentage_completed": 25,
                    "completion_state": "Failed",
                    "mirror_current_image": None,
                    "mirror_number_images": None,
                    "service_state": None,
                    "cp4d_url": None,
                    "cp4d_user": None,
                    "cp4d_password": None
                }
            ]
        }
    }


class ConfigurationUpdateRequest(BaseModel):
    configuration: Dict[str, Any] = Field(
        ...,
        description="Complete configuration object including data and metadata",
        json_schema_extra={
            "example": {
                "data": {
                    "global_config": {
                        "project": "cpd-instance",
                        "env_id": "pluto-01",
                        "cloud_platform": "existing-ocp",
                        "env_type": "development"
                    },
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
                            "cp4d_version": "4.8"
                        }
                    ]
                },
                "metadata": {
                    "config_file_path": "/path/to/config.yaml",
                    "selectedCloudPak": "software-hub"
                }
            }
        }
    )

class ConfigurationUpdateResponse(BaseModel):
    model_config = {
        "json_schema_extra": {
            "example": {
                "config": "global_config:\n- project: cpd-instance\n  env_id: pluto-01\n  cloud_platform: existing-ocp\n..."
            }
        }
    }
    
    config: str = Field(..., description="The updated configuration in YAML format")

class ConfigurationMetadata(BaseModel):
    """Metadata about the configuration state."""
    model_config = {"exclude_none": True}
    existing_config: bool = Field(..., description="Whether an existing configuration was found")
    selectedCloudPak: str = Field(..., description="Selected Cloud Pak: 'software-hub' or 'cp4i'")
    entitlementKey: Optional[str] = Field(default=None, description="Cloud Pak entitlement key from OpenShift secret (only in OpenShift context)")
    config_file_path: Optional[str] = Field(default=None, description="Path to the configuration file (only in local context)")

class ConfigurationData(BaseModel):
    """Configuration data organized by component type."""
    model_config = {"exclude_none": True}
    global_config: dict = Field(default_factory=dict, description="Global configuration settings")
    openshift: list = Field(default_factory=list, description="OpenShift cluster configuration")
    cp4d: Optional[list] = Field(default=None, description="Cloud Pak for Data configuration")
    cp4i: Optional[list] = Field(default=None, description="Cloud Pak for Integration configuration")

class FormatConfigurationRequest(BaseModel):
    """Request model for formatting configuration data into YAML."""
    data: ConfigurationData = Field(
        ...,
        description="Configuration data containing global_config, openshift, cp4d, and cp4i sections"
    )
    metadata: ConfigurationMetadata = Field(
        ...,
        description="Metadata about the configuration including selected Cloud Pak"
    )
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "data": {
                        "global_config": {
                                "project": "cpd-instance",
                                "env_id": "pluto-01",
                                "cloud_platform": "existing-ocp",
                                "env_type": "development"
                        },
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
                                "cp4d_version": "4.8"
                            }
                        ]
                    },
                    "metadata": {
                        "existing_config": True,
                        "selectedCloudPak": "software-hub"
                    }
                }
            ]
        }
    }
class FormatConfigurationResponse(BaseModel):
    """Response model for format-configuration endpoint."""
    code: int = Field(..., description="Response code: 0 for success, -1 for error")
    message: str = Field(default="", description="Response message describing the result")
    data: str = Field(default="", description="Contains the formatted YAML string")
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "code": 0,
                    "message": "",
                    "data": "---\nglobal_config:\n- project: cpd-instance\n  env_id: pluto-01\n  cloud_platform: existing-ocp\n\nopenshift:\n- name: pluto\n  ocp_version: '4.12'\n\ncp4d:\n- project: cpd-instance\n  cp4d_version: '4.8'\n"
                }
            ]
        }
    }


class ConfigurationResponse(BaseModel):
    code: int = Field(..., description="Response code: 0 for success, -1 for error")
    message: str = Field(..., description="Response message describing the result")
    content: str = Field(default="", description="Raw YAML content of the configuration")
    data: ConfigurationData = Field(..., description="Parsed configuration data organized by type")
    metadata: ConfigurationMetadata = Field(..., description="Metadata about the configuration state")

    model_config = {
        "json_schema_extra": {
            "example": {
                "code": 0,
                "message": "Configuration loaded successfully",
                "content": "global_config:\n- project: cpd-instance\n  env_id: pluto-01\n...",
                "data": {
                    "global_config": {
                            "project": "cpd-instance",
                            "env_id": "pluto-01",
                            "cloud_platform": "existing-ocp",
                            "env_type": "development",
                            "confirm_destroy": False
                    },
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
                    ]
                },
                "metadata": {
                    "existing_config": True,
                    "selectedCloudPak": "software-hub"
                }
            }
        }
    }

# Root endpoint
@app.get('/')
def index():
    return FileResponse('ww/index.html')

# Mount static files
try:
    app.mount('/static', StaticFiles(directory='ww/static'), name='static')
except RuntimeError:
    logger.warning('Static directory ww/static not found')

# API Routes (defined before catch-all)
@app.post(
    '/api/v1/mirror',
    tags=["Deployer"],
    summary="Mirror Cloud Pak images"
)
def mirror(request: MirrorRequest):
    # Request validation is handled by Pydantic model
    print(request.registry.portable)
    print(request.registry.registryHostname)
    print(request.registry.registryPort)
    print(request.registry.registryNS)
    print(request.registry.registryUser)
    print(request.registry.registryPassword)

    deployer_env = os.environ.copy()
    # Assemble the mirror command
    deploy_command=['/cloud-pak-deployer/cp-deploy.sh']
    deploy_command+=['env','download']
    deploy_command+=['-e=env_id={}'.format(request.envId)]
    deploy_command+=['-e=ibm_cp_entitlement_key={}'.format(request.entitlementKey)]

    deploy_command+=['-v']
    
    process = subprocess.Popen(deploy_command, 
                    universal_newlines=True,
                    env=deployer_env)

    return 'running'

#
# Start deployment
#

@app.post(
    '/api/v1/deploy',
    response_model=DeployResponse,
    tags=["Deployer"],
    summary="Deploy Cloud Pak",
    description="""
    Initiates the Cloud Pak deployment process.
    
    This endpoint starts the deployment of Cloud Pak for Data and related components. The behavior
    differs based on the deployment context:
    
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
    
    **Monitoring**:
    Use the `/api/v1/deployer-status` endpoint to monitor deployment progress and retrieve
    access credentials after successful completion.
    
    **Note**: This is an asynchronous operation. The endpoint returns immediately after starting
    the deployment process. Use the deployer-status endpoint to track progress.
    """
)
def deploy(request: DeployRequest):
    deployer_env = os.environ.copy()
    deployer_env['envId'] = request.envId
    deployer_env['OCP_OC_LOGIN'] = request.oc_login_command
    deployer_env['CP_ENTITLEMENT_KEY']=request.entitlementKey
    deployer_env['CONFIG_DIR']=config_dir
    deployer_env['STATUS_DIR']=status_dir
    if request.adminPassword is not None and request.adminPassword != '':
        deployer_env['adminPassword'] = request.adminPassword

    if (running_context == 'local'):
        result=deploy_local(deployer_env)
    else:
        result=deploy_openshift(deployer_env)

    return result

def deploy_local(deployer_env):
    deploy_command=['cp-deploy.sh','env']
    deploy_command+=['-e=env_id={}'.format(deployer_env['envId'])]
    deploy_command+=['-vs=oc-login={}'.format(deployer_env['OCP_OC_LOGIN'])]
    deploy_command+=['-e=ibm_cp_entitlement_key={}'.format(deployer_env['CP_ENTITLEMENT_KEY'])]
    if 'adminPassword' in deployer_env and deployer_env['adminPassword']!='':
        deploy_command+=['-e=cp4d_admin_password={}'.format(deployer_env['adminPassword'])]
    deploy_command+=['-v']
    logger.debug('Deploy command: {}'.format(deploy_command))

    process = subprocess.Popen(deploy_command,
                    universal_newlines=True,
                    env=deployer_env)

    return DeployResponse(
        status='running',
        message='Deployment started successfully in local context'
    )

def deploy_openshift(deployer_env):

    deployer_start_file = f'{deployer_dir}/scripts/deployer/assets/cloud-pak-deployer-start.yaml'
    
    # Debug: Show content of deployer-start file
    try:
        with open(deployer_start_file, 'r') as f:
            deployer_start_content = f.read()
            logger.debug(f'Content of {deployer_start_file}:\n{deployer_start_content}')
    except Exception as e:
        logger.error(f'Failed to read deployer-start file: {e}')
    
    deploy_command=['oc','create','-f', deployer_start_file]
    logger.debug('deploy command: {}'.format(deploy_command))

    process = subprocess.Popen(deploy_command,
                    universal_newlines=True,
                    env=deployer_env)

    return DeployResponse(
        status='running',
        message='Cloud Pak Deployer job creation initiated in OpenShift',
        job_name='cloud-pak-deployer'
    )

#
# Download logs
#

@app.post(
    '/api/v1/download-log',
    tags=["Deployer"],
    summary="Download Deployer Logs",
    description="""
    Downloads Cloud Pak Deployer logs as a file.
    
    This endpoint allows you to retrieve deployment logs for troubleshooting and monitoring purposes.
    The behavior differs based on the deployment context:
    
    - **Local context**: Copies logs from the STATUS_DIR/log directory
    - **OpenShift context**: Retrieves logs from the cloud-pak-deployer-debug pod
    
    **Log Types**:
    - `deployer-log`: Downloads only the main deployer log file (cloud-pak-deployer.log)
    - `all-logs`: Downloads a compressed archive containing all deployment logs (cloud-pak-deployer-logs.tar.gz)
    
    **Response**:
    - For `deployer-log`: Returns a plain text log file
    - For `all-logs`: Returns a gzipped tar archive containing all log files
    
    **Use Cases**:
    - Troubleshooting deployment failures
    - Monitoring deployment progress offline
    - Sharing logs with support teams
    - Archiving deployment records
    
    **Note**: Logs are temporarily stored in `/tmp/` before being returned to the client.
    """
)
def download_log(request: DownloadLogRequest):
    print(request.model_dump(), file=sys.stderr)

    # Request validation is handled by Pydantic model
    deployerLog = request.deployerLog
    if deployerLog != "deployer-log" and deployerLog != "all-logs":
        raise HTTPException(status_code=400, detail='Bad Request')

    if (running_context == 'local'):
        download_log_local(deployerLog)
    else:
        download_log_openshift(deployerLog)

    if deployerLog == "deployer-log":
        log_path = '/tmp/cloud-pak-deployer.log'
        return FileResponse(path=log_path, media_type='text/plain', filename='cloud-pak-deployer.log')
    else:
        log_zip = '/tmp/cloud-pak-deployer-logs.tar.gz'
        return FileResponse(path=log_zip, media_type='application/gzip', filename='cloud-pak-deployer-logs.tar.gz')
    

def download_log_local(deployerLog):
    if deployerLog == "deployer-log":
        copy2(status_dir+'/log/cloud-pak-deployer.log', '/tmp/')
    else:
        log_folder_path = status_dir + '/log/'
        with tarfile.open('/tmp/cloud-pak-deployer-logs.tar.gz', 'w:gz') as tar_file:
            for f in os.listdir(log_folder_path):
                tar_file.add(os.path.join(log_folder_path,f))
            tar_file.close()

def download_log_openshift(deployerLog):
    oc_get_debug=['oc','get',f'-n={deployer_project}','pods','-l=app=cloud-pak-deployer-debug','-o=json']
    logger.debug('Get cloud-pak-deployer debug pods: {}'.format(oc_get_debug))

    try:
        process = subprocess.Popen(oc_get_debug,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        universal_newlines=True)
        
        stdout, stderr = process.communicate()
        
        if process.returncode == 0:
            deployer_debug=json.loads(stdout)
            for dd in deployer_debug['items']:
                if 'status' in dd and 'phase' in dd['status']:
                    if dd['status']['phase'] in ['Running']:

                        if deployerLog == "deployer-log":
                            oc_get_log=['oc','cp',f'-n={deployer_project}',dd['metadata']['name']+':/Data/cpd-status/log/cloud-pak-deployer.log','/tmp/cloud-pak-deployer.log']
                            logger.debug('Get cloud-pak-deployer log: {}'.format(oc_get_log))

                            try:
                                process = subprocess.Popen(oc_get_log,
                                                stdout=subprocess.PIPE,
                                                stderr=subprocess.PIPE,
                                                universal_newlines=True)
                                
                                stdout, stderr = process.communicate()

                            except Exception as e:
                                logger.error('Error while getting /Data/cpd-status/log/cloud-pak-deployer.log from pod {}: {}'.format(dd['metadata']['name'],str(e)))
                        else:
                            oc_rsh_tar=['oc','rsh',f'-n={deployer_project}',dd['metadata']['name'],'tar','cvzf','/tmp/cloud-pak-deployer-logs.tar.gz','-C','/Data/cpd-status/log','.']
                            logger.debug('tar cloud-pak-deployer logs: {}'.format(oc_rsh_tar))

                            try:
                                process = subprocess.Popen(oc_rsh_tar,
                                                stdout=subprocess.PIPE,
                                                stderr=subprocess.PIPE,
                                                universal_newlines=True)
                                
                                stdout, stderr = process.communicate()

                            except Exception as e:
                                logger.error('Error while tarring Cloud Pak Deployer logs in pod {}: {}, not getting detailed status'.format(dd['metadata']['name'],str(e)))

                            oc_get_log_tar=['oc','cp',f'-n={deployer_project}',dd['metadata']['name']+':/tmp/cloud-pak-deployer-logs.tar.gz','/tmp/cloud-pak-deployer-logs.tar.gz']
                            logger.debug('Get cloud-pak-deployer logs: {}'.format(oc_get_log_tar))

                            try:
                                process = subprocess.Popen(oc_get_log_tar,
                                                stdout=subprocess.PIPE,
                                                stderr=subprocess.PIPE,
                                                universal_newlines=True)
                                
                                stdout, stderr = process.communicate()

                            except Exception as e:
                                logger.debug('Error while getting Cloud Pak Deployer logs from pod {}: {}, not getting detailed status'.format(dd['metadata']['name'],str(e)))

    except Exception as e:
        logger.error('Error while getting cloud-pak-deployer-debug pod: {}, not getting getting logs'.format(str(e)))

#
# OpenShift login
#

@app.post(
    '/api/v1/oc-login',
    tags=["OpenShift"],
    summary="Login to OpenShift cluster",
    description="""
    Authenticates to an OpenShift cluster using the provided `oc login` command.
    
    The command must be a valid `oc login` command with all necessary parameters such as:
    - Server URL
    - Token or username/password
    - Optional flags (--insecure-skip-tls-verify, etc.)
    
    **Example commands:**
    - `oc login https://api.cluster.example.com:6443 --token=sha256~xxxxx`
    - `oc login https://api.cluster.example.com:6443 -u admin -p password`
    
    **Returns:**
    - `code: 0` - Successfully logged in
    - `code: non-zero` - Login failed with error message
    """,
    response_description="Login result with status code and optional error message"
)
def oc_login(request: OcLoginRequest):
    result = {
        "code":-1,
        "error":"",
    }
    #print(body, file=sys.stderr)
    env = {}
    oc_login_command=request.oc_login_command
    oc_login_command = oc_login_command.strip()

    import re
    pattern = r'oc(\s+)login(\s)(.*)'
    isOcLoginCmd = re.match(pattern, oc_login_command)
    
    if isOcLoginCmd:
        proc = subprocess.Popen(oc_login_command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        outputlog, errorlog = proc.communicate()

        if  proc.returncode == 0:
            result["code"]=proc.returncode
        else:
            errors = str(errorlog,  'utf-8').split("\n")
            result={"code": proc.returncode,"error": errors[-2]}
            logger.error('Login error: {}'.format(errors))

        return result
    else:
        raise HTTPException(status_code=400, detail='Bad Request')

#
# OpenShift connection check
#

@app.get(
    '/api/v1/oc-check-connection',
    tags=["OpenShift"],
    summary="Check OpenShift connection status",
    description="""
    Checks the current OpenShift connection status and retrieves cluster information.
    
    This endpoint verifies if the user is currently logged in to an OpenShift cluster and
    retrieves detailed information about the cluster including:
    - Current logged-in user
    - OpenShift server URL
    - OpenShift cluster version
    - Kubernetes version
    
    **No authentication required** - Uses the current `oc` CLI session.
    
    **Use cases:**
    - Verify login status before performing operations
    - Display cluster information in the UI
    - Validate cluster connectivity
    - Check OpenShift and Kubernetes versions for compatibility
    
    **Implementation:**
    The endpoint executes the following commands:
    1. `oc whoami` - Retrieves the current logged-in user
    2. `oc whoami --show-server` - Retrieves the OpenShift server URL
    3. `oc version -o json` - Retrieves version information
    
    **Returns:**
    - `connected: true` - Successfully connected with cluster details
    - `connected: false` - Not connected with error message
    """,
    response_model=OcCheckConnectionResponse,
    response_description="Connection status with cluster information or error details",
    responses={
        200: {
            "description": "Connection check completed successfully",
            "content": {
                "application/json": {
                    "examples": {
                        "connected_admin": {
                            "summary": "Successfully Connected (Admin User)",
                            "description": "User is logged in as cluster admin with full cluster information",
                            "value": {
                                "connected": True,
                                "user": "kube:admin",
                                "server": "https://api.ocp-cluster.example.com:6443",
                                "cluster_version": "4.14.3",
                                "kubernetes_version": "v1.27.6+f67aeb3",
                                "error": ""
                            }
                        },
                        "connected_developer": {
                            "summary": "Successfully Connected (Regular User)",
                            "description": "User is logged in as a regular developer with full cluster information",
                            "value": {
                                "connected": True,
                                "user": "developer",
                                "server": "https://api.openshift-prod.company.com:6443",
                                "cluster_version": "4.12.45",
                                "kubernetes_version": "v1.25.16+9ce3e04",
                                "error": ""
                            }
                        },
                        "not_connected": {
                            "summary": "Not Logged In",
                            "description": "User is not logged in to any OpenShift cluster",
                            "value": {
                                "connected": False,
                                "user": "",
                                "server": "",
                                "cluster_version": "",
                                "kubernetes_version": "",
                                "error": "Not logged in to OpenShift cluster"
                            }
                        },
                        "partial_info": {
                            "summary": "Partial Information (Version Retrieval Failed)",
                            "description": "User is connected but version information could not be retrieved",
                            "value": {
                                "connected": True,
                                "user": "system:serviceaccount:default:deployer",
                                "server": "https://api.cluster.local:6443",
                                "cluster_version": "",
                                "kubernetes_version": "",
                                "error": ""
                            }
                        }
                    }
                }
            }
        }
    }
)
def oc_check_connection() -> OcCheckConnectionResponse:
    result = {
        "connected": False,
        "user": "",
        "server": "",
        "cluster_version": "",
        "kubernetes_version": "",
        "error": ""
    }
    
    logger.debug("Checking OpenShift connection status")
    
    # Step 1: Check if user is logged in with 'oc whoami'
    try:
        proc = subprocess.Popen(
            'oc whoami',
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True
        )
        stdout, stderr = proc.communicate()
        
        if proc.returncode == 0:
            result["user"] = str(stdout, 'utf-8').strip()
            logger.debug(f"Connected as user: {result['user']}")
        else:
            error_msg = str(stderr, 'utf-8').strip()
            result["error"] = "Not logged in to OpenShift cluster"
            logger.error(f"Not connected: {error_msg}")
            return result
            
    except Exception as e:
        result["error"] = f"Error checking connection: {str(e)}"
        logger.error(f"Exception during oc whoami: {str(e)}")
        return result
    
    # Step 2: Get server URL with 'oc whoami --show-server'
    try:
        proc = subprocess.Popen(
            'oc whoami --show-server',
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True
        )
        stdout, stderr = proc.communicate()
        
        if proc.returncode == 0:
            result["server"] = str(stdout, 'utf-8').strip()
            logger.debug(f"Server URL: {result['server']}")
        else:
            logger.warning("Could not retrieve server URL")
            
    except Exception as e:
        logger.error(f"Exception during oc whoami --show-server: {str(e)}")
    
    # Step 3: Get version info with 'oc version -o json'
    try:
        proc = subprocess.Popen(
            'oc version -o json',
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True
        )
        stdout, stderr = proc.communicate()
        
        if proc.returncode == 0:
            version_data = json.loads(str(stdout, 'utf-8'))
            
            # Extract OpenShift version
            if 'openshiftVersion' in version_data:
                result["cluster_version"] = version_data['openshiftVersion']
            
            # Extract Kubernetes version from server version
            if 'serverVersion' in version_data and 'gitVersion' in version_data['serverVersion']:
                result["kubernetes_version"] = version_data['serverVersion']['gitVersion']
            
            logger.debug(f"Cluster version: {result['cluster_version']}, Kubernetes version: {result['kubernetes_version']}")
        else:
            logger.warning("Could not retrieve version information")
            
    except json.JSONDecodeError as e:
        logger.error(f"Error parsing version JSON: {str(e)}")
    except Exception as e:
        logger.error(f"Exception during oc version: {str(e)}")
    
    result["connected"] = True
    logger.debug("OpenShift connection check completed successfully")
    
    return result

#
# Deployer status
#

@app.get(
    '/api/v1/deployer-status',
    response_model=DeployerStatusResponse,
    tags=["Deployer"],
    summary="Get deployer status",
    description="""
    Retrieves the current status of the Cloud Pak Deployer.
    
    This endpoint provides real-time information about the deployment process, including:
    - Whether the deployer is currently active
    - Current deployment stage and progress
    - Completion status (successful, failed, or in progress)
    - Cloud Pak access credentials (when deployment is complete)
    
    The behavior differs based on the deployment context:
    - **Local context**: Checks for running `cp-deploy.sh` processes
    - **OpenShift context**: Queries deployer job and pod status
    
    **Deployment Stages**:
    - `validate`: Validating configuration
    - `prepare`: Preparing environment
    - `provision-infra`: Provisioning infrastructure
    - `configure-infra`: Configuring infrastructure
    - `install-cloud-pak`: Installing Cloud Pak
    - `configure-cloud-pak`: Configuring Cloud Pak
    - `deploy-assets`: Deploying assets
    - `smoke-tests`: Running smoke tests
    
    **Use Cases**:
    - Monitor deployment progress in real-time
    - Check if deployment is active
    - Retrieve Cloud Pak access credentials after successful deployment
    - Determine deployment completion status
    - Track mirroring progress during image mirror operations
    """
)
def get_deployer_status():
    result = {}

    if (running_context == 'local'):
        result=get_deployer_status_local()
    else:
        result=get_deployer_status_openshift()

    logger.debug(f"Deployer status: {result}")

    return result

def get_deployer_status_local():
    result = {}
    # Check if the env apply process is active
    result['deployer_active']=False
    for proc in psutil.process_iter():
        if (proc.username() == getpass.getuser()):
            try:
                # logger.debug(proc.cmdline())
                if 'cp-deploy.sh' in proc.cmdline() and \
                    'env' in proc.cmdline() and ('apply' in proc.cmdline() or 'download' in proc.cmdline()):
                    result['deployer_active']=True
            except:
                pass
    deploy_state_log_path = status_dir + '/state/deployer-state.out'
    get_deployer_status_details(deploy_state_log_path, result)
    return(result)

def get_deployer_status_openshift():
    result = {}
    # Check if the env apply process is active
    deployer_starting=False
    result['deployer_active']=False

    oc_get_deployer_start=['oc','get',f'-n={deployer_project}','pods','-l=app=cloud-pak-deployer-start','-o=json']
    logger.debug('Get cloud-pak-deployer-start pods: {}'.format(oc_get_deployer_start))

    try:
        process = subprocess.Popen(oc_get_deployer_start,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        universal_newlines=True)
        
        stdout, stderr = process.communicate()
        
        if process.returncode == 0:
            deployer_start_pods=json.loads(stdout)
            for ds in deployer_start_pods['items']:
                if 'status' in ds and 'phase' in ds['status']:
                    if ds['status']['phase'] in ['Pending','Running']:
                        result['deployer_active']=True
                        deployer_starting=True
        
    except Exception as e:
        logger.error('Error while getting cloud-pak-deployer-start pods: {}, assuming deployer is not started'.format(str(e)))
        result['deployer_active']=False

    if (not deployer_starting):
        oc_get_deployer=['oc','get',f'-n={deployer_project}','job','cloud-pak-deployer','-o=json']
        logger.debug('Get cloud-pak-deployer job: {}'.format(oc_get_deployer))

        try:
            process = subprocess.Popen(oc_get_deployer,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,
                            universal_newlines=True)
            
            stdout, stderr = process.communicate()
            
            if process.returncode == 0:
                result['deployer_active']=True
                deployer_job=json.loads(stdout)
                conditions = deployer_job.get('status', {}).get('conditions', [])
                for condition in conditions:
                    if condition.get('type','')=='Failed':
                        result['deployer_active']=False
                        result['completion_state']='Failed'
                    elif condition.get('type','')=='Complete':
                        result['deployer_active']=False
                        result['completion_state']='Successful'
            
        except Exception as e:
            logger.error('Error while getting cloud-pak-deployer pods: {}, assuming deployer is not started'.format(str(e)))
            result['deployer_active']=False

        oc_get_debug=['oc','get',f'-n={deployer_project}','pods','-l=app=cloud-pak-deployer-debug','-o=json']
        logger.debug('Get cloud-pak-deployer debug pods: {}'.format(oc_get_debug))

        try:
            process = subprocess.Popen(oc_get_debug,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,
                            universal_newlines=True)
            
            stdout, stderr = process.communicate()
            
            if process.returncode == 0:
                deployer_debug=json.loads(stdout)
                for dd in deployer_debug['items']:
                    if dd.get('status',{}).get('phase','') in ['Running']:
                        oc_get_state=['oc','cp',f'-n={deployer_project}',dd['metadata']['name']+':/Data/cpd-status/state/deployer-state.out','/tmp/deployer-state.out']
                        logger.debug('Get cloud-pak-deployer state: {}'.format(oc_get_state))

                        try:
                            process = subprocess.Popen(oc_get_state,
                                            stdout=subprocess.PIPE,
                                            stderr=subprocess.PIPE,
                                            universal_newlines=True)
                            
                            stdout, stderr = process.communicate()

                            if process.returncode == 0:
                                deploy_state_log_path = '/tmp/deployer-state.out'
                                result=get_deployer_status_details(deploy_state_log_path, result)
                            
                        except Exception as e:
                            logger.error('Error while getting deployer state from pod {}: {}, not getting detailed status'.format(dd['metadata']['name'],str(e)))

        except Exception as e:
            logger.error('Error while getting cloud-pak-deployer-debug pod: {}, not getting detailed status'.format(str(e)))

    return(result)

def get_deployer_status_details(deploy_state_log_path, result):
    logger.debug('Retrieving state from {}'.format(deploy_state_log_path))
    try:
        with open(deploy_state_log_path, "r", encoding='UTF-8') as f:
            temp={}
            content = f.read().replace('\\','')
            f.close()
            logger.debug('Content of state file: {}'.format(content))
            docs=yaml.safe_load_all(content)
            for doc in docs:
                temp={**temp, **doc}
            
            fields = [
                'deployer_stage', 'last_step', 'percentage_completed',
                'completion_state', 'mirror_current_image', 'mirror_number_images',
                'service_state', 'cp4d_url', 'cp4d_user', 'cp4d_password'
            ]
            for field in fields:
                if field in temp:
                    result[field] = temp[field]

    except FileNotFoundError:
        logger.warning('Error while reading file {}'.format(deploy_state_log_path))
    except PermissionError:
        logger.warning('Permission error while reading file {}'.format(deploy_state_log_path))
    except IOError:
        logger.warning('IO Error while reading file {}'.format(deploy_state_log_path))
    except Exception as e:
        logger.warning('Internal server error: {}'.format(e))

    return result

#
# Delete deployer job
#

@app.delete(
    '/api/v1/delete-deployer-job',
    response_model=DeleteDeployerJobResponse,
    tags=["Deployer"],
    summary="Delete deployer job",
    description="""
    Deletes the Cloud Pak Deployer job and related pods in OpenShift.
    
    This endpoint removes the deployer job from the OpenShift cluster, which will also terminate
    any associated pods. This is useful for:
    
    - **Cleaning up after deployment**: Remove the deployer job after successful completion
    - **Stopping failed deployments**: Terminate a deployment that has failed or is stuck
    - **Restarting deployments**: Delete the existing job before starting a new deployment
    - **Resource management**: Free up cluster resources by removing completed jobs
    
    **Important Notes**:
    - This operation is **only available for OpenShift deployments** (not local context)
    - The job deletion is idempotent - it will not fail if the job doesn't exist
    - Deleting the job will terminate any running deployment process
    - This does not delete the deployed Cloud Pak instances, only the deployer job itself
    - Configuration files and status information are preserved
    
    **Prerequisites**:
    - Must be running in OpenShift context (CPD_CONTEXT=openshift)
    - User must have permissions to delete jobs in the deployer namespace
    - The `oc` CLI must be installed and configured
    
    **Use Cases**:
    1. **Post-deployment cleanup**: After a successful deployment, remove the job to clean up resources
    2. **Error recovery**: If a deployment fails, delete the job before attempting a new deployment
    3. **Deployment restart**: Delete the existing job to start a fresh deployment with updated configuration
    4. **Resource optimization**: Remove completed jobs to free up cluster resources
    
    **What Gets Deleted**:
    - The `cloud-pak-deployer` Kubernetes Job
    - All pods created by the job (automatically cleaned up by Kubernetes)
    
    **What Is Preserved**:
    - Deployed Cloud Pak instances and their resources
    - Configuration files in ConfigMaps
    - Status information and logs (if already retrieved)
    - OpenShift cluster and infrastructure
    """
)
def delete_deployer_job():
    result = {'success': False, 'message': ''}
    
    if running_context == 'local':
        result['message'] = 'Delete operation is only available for OpenShift deployments'
        return JSONResponse(status_code=400, content=result)
    
    try:
        # Delete the cloud-pak-deployer job
        delete_job_command = ['oc', 'delete', f'-n={deployer_project}', 'job', 'cloud-pak-deployer', '--ignore-not-found=true']
        logger.debug('Delete job command: {}'.format(delete_job_command))
        
        process = subprocess.Popen(delete_job_command,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        universal_newlines=True)
        
        stdout, stderr = process.communicate()
        
        if process.returncode != 0:
            logger.error(f"Error deleting job: {stderr}")
            result['message'] = f"Error deleting job: {stderr}"
            return JSONResponse(status_code=500, content=result)
        
        result['success'] = True
        result['message'] = 'Cloud Pak Deployer job and related pods deleted successfully'
        logger.debug('Successfully deleted cloud-pak-deployer job and pods')
        return result
        
    except Exception as e:
        logger.error(f"Exception while deleting deployer job: {str(e)}")
        result['message'] = f"Exception: {str(e)}"
        return JSONResponse(status_code=500, content=result)


#
# Deployer configuration
#

@app.get(
    '/api/v1/configuration',
    response_model=ConfigurationResponse,
    response_model_exclude_none=True,
    summary="Get Configuration",
    description="""
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
    """,
    responses={
        200: {
            "description": "Configuration retrieved successfully",
            "content": {
                "application/json": {
                    "examples": {
                        "existing_config": {
                            "summary": "Existing Configuration",
                            "description": "Response when an existing configuration is found",
                            "value": {
                                "code": 0,
                                "message": "Configuration loaded successfully",
                                "content": "global_config:\n- project: cpd-instance\n  env_id: pluto-01\n...",
                                "data": {
                                    "global_config": {
                                            "project": "cpd-instance",
                                            "env_id": "pluto-01",
                                            "cloud_platform": "existing-ocp",
                                            "env_type": "development",
                                            "confirm_destroy": False
                                    },
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
                                    ]
                                },
                                "metadata": {
                                    "existing_config": True,
                                    "selectedCloudPak": "software-hub",
                                    "entitlementKey": "eyJhbGc..."
                                }
                            }
                        },
                        "no_existing_config": {
                            "summary": "No Existing Configuration",
                            "description": "Response when no existing configuration is found, returns defaults",
                            "value": {
                                "code": 0,
                                "message": "Successfully created new configuration.",
                                "content": "",
                                "data": {
                                    "global_config": {
                                            "project": "sample",
                                            "env_id": "sample",
                                            "cloud_platform": "existing-ocp"
                                    },
                                    "openshift": [],
                                    "cp4d": []
                                },
                                "metadata": {
                                    "existing_config": False,
                                    "selectedCloudPak": "software-hub"
                                }
                            }
                        }
                    }
                }
            }
        }
    },
    tags=["Configuration"]
)
def read_configuration():
    config_result: dict[str, Any] = {
        "code":-1,
        "message":"",
        "content":"",
        "data":{},
        "metadata":{},
    }

    read_result={}
    if (running_context == 'local'):
        read_result = read_configuration_from_file()
    else:
        read_result = read_configuration_from_openshift()

    logger.debug(f'read_result: {read_result}')

    if (read_result['code'] == 0):
        config_result['metadata']=read_result['metadata']
        config_result['content']=read_result['content']
        if (read_result['metadata']['existing_config']):
            logger.debug(config_result['content'])
            temp=yaml.load(read_result['content'], Loader=yaml.FullLoader)

            if 'global_config' in temp:
                config_result['data']['global_config']=temp['global_config']
            else:
                logger.debug("Loading base global_config data from {}".format(cp_base_config_path+'/ocp-existing-ocp-auto.yaml'))
                config_result['data']['global_config']=loadYamlFile(cp_base_config_path+'/ocp-existing-ocp-auto.yaml')['global_config']

            if 'openshift' in temp:
                config_result['data']['openshift']=temp['openshift']
            else:
                logger.debug("Loading base openshift data from {}".format(cp_base_config_path+'/ocp-existing-ocp-auto.yaml'))
                config_result['data']['openshift']=loadYamlFile(cp_base_config_path+'/ocp-existing-ocp-auto.yaml')['openshift']

            if 'cp4d' in temp:
                config_result['data']['cp4d']=temp['cp4d']
                config_result['metadata']['selectedCloudPak'] = 'software-hub'
            elif 'cp4i' in temp:
                config_result['data']['cp4i']=temp['cp4i']
                config_result['metadata']['selectedCloudPak'] = 'cp4i'
            else:
                logger.debug("Loading base cp4d data from {}".format(cp_base_config_path+'/cp4d-latest.yaml'))
                config_result['data']['cp4d']=loadYamlFile(cp_base_config_path+'/cp4d-latest.yaml')['cp4d']
                logger.debug("Loading base cp4i data from {}".format(cp_base_config_path+'/cp4i-latest.yaml'))
                config_result['data']['cp4i']=loadYamlFile(cp_base_config_path+'/cp4i-latest.yaml')['cp4i']
                config_result['metadata']['selectedCloudPak'] = 'software-hub'
            
            if 'env_id' not in config_result['data']['global_config']:
                config_result['data']['global_config']['env_id']='demo'
                logger.warning("Added env_id to global_config: {}".format(config_result['data']['global_config']))

            config_result['code'] = 0
            config_result['message'] = "Successfully converted input to configuration."
            logger.debug('Result of reading configuration: {}'.format(json.dumps(config_result,indent=2)))
        else:
            logger.debug("Loading base global_config data from {}".format(cp_base_config_path+'/ocp-existing-ocp-auto.yaml'))
            config_result['data']['global_config']=loadYamlFile(cp_base_config_path+'/ocp-existing-ocp-auto.yaml')['global_config']
            logger.debug("Loading base openshift data from {}".format(cp_base_config_path+'/ocp-existing-ocp-auto.yaml'))
            config_result['data']['openshift']=loadYamlFile(cp_base_config_path+'/ocp-existing-ocp-auto.yaml')['openshift']
            logger.debug("Loading base cp4d data from {}".format(cp_base_config_path+'/cp4d-latest.yaml'))
            config_result['data']['cp4d']=loadYamlFile(cp_base_config_path+'/cp4d-latest.yaml')['cp4d']
            # cp4i is optional - only load base data for new configurations
            logger.debug("Loading base cp4i data from {}".format(cp_base_config_path+'/cp4i-latest.yaml'))
            config_result['data']['cp4i']=loadYamlFile(cp_base_config_path+'/cp4i-latest.yaml')['cp4i']
            config_result['metadata']['selectedCloudPak'] = 'software-hub'
            config_result['code'] = 0
            config_result['message'] = "Successfully created new configuration."
            logger.debug('Result of creating configuration: {}'.format(json.dumps(config_result,indent=2)))

    return config_result

def read_configuration_from_file() -> dict[str, Any]:
    file_result = {
        "code":-1,
        "message":"",
        "content":"",
        "metadata":{},
    }
    """
    Read configuration content from a YAML file.
    """
    existing_config=False
    found_config_files=glob.glob(config_dir+'/config/*.yaml')
    if len(found_config_files) == 0:
        generated_config_yaml_path = config_dir+'/config/cpd-config.yaml'
        existing_config=False
    elif len(found_config_files) > 1:
        errmsg="More than 1 yaml file found in directory {}. Wizard can be used for 0 or 1 config files.".format(config_dir+'/config')
        logger.error(errmsg)
        file_result['code'] = 400
        file_result['message'] = errmsg
        return file_result
    else:
        generated_config_yaml_path = found_config_files[0]
        existing_config=True

    file_result['metadata']['existing_config'] = existing_config

    logger.debug('Config file that will be used is {}'.format(generated_config_yaml_path))
    file_result['metadata']['config_file_path'] = generated_config_yaml_path
    if (existing_config):
        try:
            with open(generated_config_yaml_path, "r", encoding='UTF-8') as f:
                content = f.read()
                f.close()
                file_result['content'] = content
            file_result['code'] = 0
            file_result['content'] = content
            file_result['message'] = "Successfully retrieved configuration from file {}".format(generated_config_yaml_path)
            logger.debug("Successfully retrieved configuration from file {}".format(generated_config_yaml_path))
        except FileNotFoundError:
            file_result['code'] = 404
            file_result['message'] = "Configuration File is not found."
            logger.warning('Error while reading file {}'.format(generated_config_yaml_path))
        except PermissionError:
            file_result['code'] = 401
            file_result['message'] = "Permission Error."
        except IOError:
            file_result['code'] = 101
            file_result['message'] = "IO Error."
    else:
        file_result['code'] = 0

    return file_result

def read_configuration_from_openshift() -> dict[str, Any]:
    config_result = {
        "code":-1,
        "message":"",
        "content":"",
        "metadata":{},
    }
    """
    Read configuration content from an OpenShift ConfigMap
    """
    
    config_result['metadata']['existing_config'] = False
    
    # Get configuration from the cloud-pak-deployer-config configmap
    cm_command=['oc']
    cm_command += ['extract',f'-n={deployer_project}','configmap/cloud-pak-deployer-config','--keys=cpd-config.yaml','--to=-']
    logger.debug('Retrieving config map command: {}'.format(cm_command))

    try:
        process = subprocess.Popen(cm_command,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        universal_newlines=True)
        
        stdout, stderr = process.communicate()
        
        if process.returncode == 0:
            config_result['metadata']['existing_config'] = True
            config_result['content']=stdout
            config_result['message'] = "Successfully retrieved configuration from config map"
        else:
            config_result['metadata']['existing_config'] = False
            config_result['content']=""
            config_result['message'] = "Config map not retrieved, assuming non-existing config"
        
        logger.debug(f"Successfully executed oc extract command. Output length: {len(stdout)}")
        
    except subprocess.SubprocessError as e:
        logger.debug('Subprocess error while retrieving config map: {}, assuming non-existing config'.format(str(e)))
        config_result['message'] = "Config map not retrieved, assuming non-existing config. Error: {}".format(str(e))
        config_result['metadata']['existing_config'] = False
        config_result['content']=""
    except Exception as e:
        logger.debug('Error while retrieving config map: {}, assuming non-existing config'.format(str(e)))
        config_result['message'] = "Config map not retrieved, assuming non-existing config. Error: {}".format(str(e))
        config_result['metadata']['existing_config'] = False
        config_result['content']=""

    entitlement_command=['oc']
    entitlement_command += ['extract',f'-n={deployer_project}','secret/cloud-pak-entitlement-key','--keys=cp-entitlement-key','--to=-']
    logger.debug('Retrieving secret command: {}'.format(entitlement_command))

    try:
        process = subprocess.Popen(entitlement_command,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        universal_newlines=True)
        
        stdout, stderr = process.communicate()

        if process.returncode == 0:
            config_result['metadata']['entitlementKey']=stdout
            logger.debug("Successfully retrieved entitlement key from secret")
        else:
            logger.debug("Secret not retrieved, entitlement key not set")
        
    except Exception as e:
        logger.debug('Error while retrieving secret: {}, assuming non-existing entitlement key'.format(str(e)))
    
    config_result['code'] = 0

    logger.debug(config_result)

    return config_result

@app.put(
    '/api/v1/configuration',
    response_model=ConfigurationUpdateResponse,
    summary="Update Configuration",
    description="""
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
    """,
    responses={
        200: {
            "description": "Configuration updated successfully",
            "content": {
                "application/json": {
                    "examples": {
                        "success": {
                            "summary": "Successful Update",
                            "description": "Configuration was successfully saved and formatted",
                            "value": {
                                "config": "global_config:\n- project: cpd-instance\n  env_id: pluto-01\n  cloud_platform: existing-ocp\n  env_type: development\n  confirm_destroy: false\n\nopenshift:\n- name: pluto\n  ocp_version: '4.12'\n  cluster_name: pluto\n  domain_name: example.com\n  openshift_storage:\n  - storage_name: ocs-storage\n    storage_type: ocs\n    ocs_storage_label: ocs\n    ocs_storage_size_gb: 500\n\ncp4d:\n- project: cpd-instance\n  openshift_cluster_name: pluto\n  cp4d_version: '4.8'\n  cartridges:\n  - name: cp-foundation\n    license_service:\n      state: disabled\n  - name: lite\n    version: 4.8.0\n    size: small\n"
                            }
                        }
                    }
                }
            }
        },
        400: {
            "description": "Invalid configuration data",
            "content": {
                "application/json": {
                    "example": {
                        "detail": "Invalid configuration format"
                    }
                }
            }
        }
    },
    tags=["Configuration"]
)
def update_configuration(request: ConfigurationUpdateRequest):
    full_configuration = request.configuration
    logger.debug("Full configuration: {}".format(json.dumps(full_configuration, indent=4)))

    read_result={}
    if (running_context == 'local'):
        result=update_configuration_file(full_configuration)
    else:
        result=update_configuration_openshift(full_configuration)

    return result

def update_configuration_file(full_configuration):

    all_in_one = format_configuration_yaml(full_configuration)
        
    with open(full_configuration['metadata']['config_file_path'], 'w', encoding='UTF-8') as f1:
        f1.write(all_in_one)
        f1.close()

    with open(full_configuration['metadata']['config_file_path'], "r", encoding='UTF-8') as f1:
        result={}
        result["config"]=f1.read()
        f1.close()

    vault_comand=['cp-deploy.sh','vault','set']
    vault_comand+=[f'-vs=ibm_cp_entitlement_key={full_configuration['metadata']['entitlementKey']}']
    logger.debug('Vault set command: {}'.format(vault_comand))

    process = subprocess.Popen(vault_comand, 
                    universal_newlines=True)

    return result

def update_configuration_openshift(full_configuration):

    all_in_one = format_configuration_yaml(full_configuration)

    with open('/tmp/cpd-config.yaml', 'w', encoding='UTF-8') as f1:
        f1.write(all_in_one)
        f1.close()

    with open('/tmp/cpd-config.yaml', "r", encoding='UTF-8') as f1:
        result={}
        result["config"]=f1.read()
        f1.close()

    # First try to create config map, in case it doesn't exist yet
    create_cm_command=['oc','create',f'-n={deployer_project}','configmap','cloud-pak-deployer-config']
    logger.debug('Create config map command: {}'.format(create_cm_command))

    process = subprocess.Popen(create_cm_command,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    universal_newlines=True)
    
    stdout, stderr = process.communicate()
    
    # Update the config map
    if process.returncode != 0:
        logger.debug(f"Error creating config map: {stderr}, ignoring")

    update_cm_command=['oc','set','data',f'-n={deployer_project}','configmap/cloud-pak-deployer-config','--from-file=cpd-config.yaml=/tmp/cpd-config.yaml']
    logger.debug('Set data for config map command: {}'.format(update_cm_command))

    process = subprocess.Popen(update_cm_command,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    universal_newlines=True)
    
    stdout, stderr = process.communicate()
    
    if process.returncode != 0:
        logger.debug(f"Error creating updating config map: {stderr}")        

    create_secret_command=['oc','create',f'-n={deployer_project}','secret','generic','cloud-pak-entitlement-key']
    logger.debug('Create secret command: {}'.format(create_secret_command))

    process = subprocess.Popen(create_secret_command,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    universal_newlines=True)
    
    stdout, stderr = process.communicate()
    
    # Update the config map
    if process.returncode != 0:
        logger.debug(f"Error creating secret: {stderr}, ignoring")

    update_secret_command=['oc','set','data',f'-n={deployer_project}','secret/cloud-pak-entitlement-key',f'--from-literal=cp-entitlement-key={full_configuration['metadata']['entitlementKey']}']
    logger.debug('Set data for secret command: {}'.format(update_secret_command))

    process = subprocess.Popen(update_secret_command,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    universal_newlines=True)
    
    stdout, stderr = process.communicate()
    
    if process.returncode != 0:
        logger.error(f"Error updating secret: {stderr}")      

    return result

#
# Format configuration YAML
#

@app.post(
    '/api/v1/format-configuration',
    response_model=FormatConfigurationResponse,
    summary="Format Configuration to YAML",
    description="""
    Formats the provided configuration data into a properly structured YAML string.
    
    This endpoint takes configuration data organized by component type (global_config, openshift, cp4d, cp4i)
    and converts it into a formatted YAML string suitable for deployment. The formatting includes:
    
    - Proper YAML structure with document separators
    - Sorted CP4D configuration keys by priority
    - Consistent indentation and formatting
    - Support for both Cloud Pak for Data (software-hub) and Cloud Pak for Integration (cp4i)
    
    The formatted YAML can be used for:
    - Preview before saving configuration
    - Validation of configuration structure
    - Direct use in deployment files
    """,
    tags=["Configuration"],
    responses={
        200: {
            "description": "Configuration successfully formatted",
            "content": {
                "application/json": {
                    "example": {
                        "code": 0,
                        "message": "",
                        "data": {
                            "formatted_yaml": "---\nglobal_config:\n- project: cpd-instance\n  env_id: pluto-01\n  cloud_platform: existing-ocp\n  env_type: development\n\nopenshift:\n- name: pluto\n  ocp_version: '4.12'\n  cluster_name: pluto\n  domain_name: example.com\n\ncp4d:\n- project: cpd-instance\n  openshift_cluster_name: pluto\n  cp4d_version: '4.8'\n  cartridges:\n  - name: cp-foundation\n    license_service:\n      state: disabled\n  - name: lite\n    version: 4.8.0\n    size: small\n"
                        }
                    }
                }
            }
        },
        400: {
            "description": "Invalid request - missing or malformed configuration data"
        },
        500: {
            "description": "Internal server error during formatting"
        }
    }
)
def format_configuration(request: FormatConfigurationRequest):
    """
    Format configuration data into YAML structure.
    
    Args:
        request: FormatConfigurationRequest containing data and metadata
        
    Returns:
        FormatConfigurationResponse with formatted YAML in data.formatted_yaml
        
    The function processes the configuration in the following order:
    1. Global configuration settings
    2. OpenShift cluster configuration
    3. Cloud Pak for Data configuration (if selectedCloudPak is 'software-hub')
    4. Cloud Pak for Integration configuration (if selectedCloudPak is 'cp4i')
    """
    formatted_config: dict[str, Any] = {
        "code":-1,
        "message":"",
        "data":{},
    }

    logger.debug(f"Request: {request.model_dump()}")

    formatted_config['data']=format_configuration_yaml(request.model_dump())
    formatted_config['code'] = 0

    logger.debug(f"formatted_config: {formatted_config}")

    return formatted_config


def format_configuration_yaml(full_configuration):
    global_config_yaml = yaml.safe_dump({'global_config': full_configuration['data']['global_config']})
    all_in_one = '---\n'+global_config_yaml

    openshift_yaml = yaml.safe_dump({'openshift': full_configuration['data']['openshift']})
    all_in_one = all_in_one + '\n\n' + openshift_yaml

    # cp4d is optional - only include if present and has content
    if 'cp4d' in full_configuration['data'] and full_configuration['data']['cp4d'] and len(full_configuration['data']['cp4d']) > 0:
        if full_configuration['metadata']['selectedCloudPak'] == 'software-hub':
            # Sort cp4d dictionary by value type before dumping
            cp4d_data = full_configuration['data']['cp4d']
            if isinstance(cp4d_data, list):
                # If cp4d is a list, sort each dictionary in the list
                sorted_cp4d_data = []
                for item in cp4d_data:
                    if isinstance(item, dict):
                        sorted_item = dict(sort_cp4d_dict(item.items()))
                        sorted_cp4d_data.append(sorted_item)
                    else:
                        sorted_cp4d_data.append(item)
                cp4d_yaml = yaml.safe_dump({'cp4d': sorted_cp4d_data}, sort_keys=False)
            else:
                # If cp4d is a dict, sort it
                sorted_cp4d = dict(sort_cp4d_dict(cp4d_data.items()))
                cp4d_yaml = yaml.safe_dump({'cp4d': sorted_cp4d}, sort_keys=False)
            all_in_one = all_in_one + '\n\n' + cp4d_yaml
    
    # cp4i is optional - only include if present and has content
    if 'cp4i' in full_configuration['data'] and full_configuration['data']['cp4i'] and len(full_configuration['data']['cp4i']) > 0:
        if full_configuration['metadata']['selectedCloudPak'] == 'cp4i':
            cp4i_yaml=yaml.safe_dump({'cp4i': full_configuration['data']['cp4i']})
            all_in_one = all_in_one + '\n\n' + cp4i_yaml

    return all_in_one

def sort_cp4d_dict(items):
    """
    Sort cp4d dictionary items with specific key ordering:
    1. project (if exists)
    2. operators_project (if exists)
    3. cp4d_version (if exists)
    4. Then by value type:
       - Scalars (str, int, float, bool, None)
       - Lists of scalars
       - Lists of dictionaries
       - Dictionaries
    """
    # Define priority keys and their order
    priority_keys = ['project', 'operators_project', 'cp4d_version']
    
    def get_sort_key(item):
        key, value = item
        
        # Check if key is in priority list
        if key in priority_keys:
            # Return negative priority to ensure these come first
            return (-1000 + priority_keys.index(key), key)
        
        # For non-priority keys, sort by value type
        # Scalars get priority 0
        if isinstance(value, (str, int, float, bool, type(None))):
            return (0, key)
        # Lists get priority 1 or 2 depending on content
        elif isinstance(value, list):
            if len(value) == 0:
                return (1, key)
            # Check if list contains dictionaries
            if any(isinstance(v, dict) for v in value):
                return (2, key)  # List of dicts
            else:
                return (1, key)  # List of scalars
        # Dictionaries get priority 3
        elif isinstance(value, dict):
            return (3, key)
        # Everything else gets priority 4
        else:
            return (4, key)
    
    return sorted(items, key=get_sort_key)


def loadYamlFile(path):
    result={}
    content=""
    try:
        with open(path, 'r', encoding='UTF-8') as f1:
            content=f1.read()
            docs=yaml.safe_load_all(content)
            for doc in docs:
                result={**result, **doc}
    except:
        logger.error('Error while reading file {}'.format(path))
        raise Exception('Error while reading file {}'.format(path))
    return result

@app.get(
    '/api/v1/environment-variable',
    tags=["Configuration"],
    summary="Get environment variables"
)
def environmentVariable():
    result={}

    running_context=str(os.getenv('CPD_CONTEXT', default='local'))

    result['CPD_WIZARD_PAGE_TITLE']=os.getenv('CPD_WIZARD_PAGE_TITLE', default='Cloud Pak Deployer')
    result['CPD_WIZARD_MODE']=os.getenv('CPD_WIZARD_MODE', default='')
    result['STATUS_DIR']=os.getenv('STATUS_DIR', default='')
    result['CONFIG_DIR']=os.getenv('CONFIG_DIR', default='')
    result['CPD_CONTEXT']=os.getenv('CPD_CONTEXT', default='local')

    return result


# SPA catch-all route (must be last to not interfere with API routes)
@app.get('/{full_path:path}')
def serve_spa(full_path: str):
    file_path = Path('ww') / full_path
    if file_path.is_file():
        return FileResponse(file_path)
    if not full_path.startswith('api/'):
        return FileResponse('ww/index.html')
    raise HTTPException(status_code=404, detail="Not found")
