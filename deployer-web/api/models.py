"""
Pydantic models for Cloud Pak Deployer API.

This module contains all request and response models used by the FastAPI endpoints.
"""

from typing import Any, Optional, Dict, Literal, List
from pydantic import BaseModel, Field


class RegistryConfig(BaseModel):
    """Configuration for container registry."""
    portable: bool
    registryHostname: str
    registryPort: str
    registryNS: str
    registryUser: str
    registryPassword: str


class MirrorRequest(BaseModel):
    """Request model for mirroring Cloud Pak images."""
    envId: str
    entitlementKey: str
    registry: RegistryConfig


class DeployRequest(BaseModel):
    """Request model for deploying Cloud Pak."""
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
    """Request model for OpenShift login."""
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
    """Request model for updating configuration."""
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
    """Response model for configuration update."""
    config: str = Field(..., description="The updated configuration in YAML format")
    
    model_config = {
        "json_schema_extra": {
            "example": {
                "config": "global_config:\n- project: cpd-instance\n  env_id: pluto-01\n  cloud_platform: existing-ocp\n..."
            }
        }
    }


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
    """Response model for configuration read endpoint."""
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