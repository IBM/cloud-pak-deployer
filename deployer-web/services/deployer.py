"""
Deployer service for Cloud Pak Deployer.

This module handles deployment operations including mirroring images,
starting deployments, and managing deployer jobs.
"""

import os
import subprocess
import logging
from typing import Dict

from api.models import MirrorRequest, DeployRequest, DeployResponse, DeleteDeployerJobResponse
from api.dependencies import (
    get_deployer_dir,
    get_running_context,
    get_deployer_project,
    get_config_dir,
    get_status_dir
)

logger = logging.getLogger(__name__)


def mirror_images(request: MirrorRequest) -> str:
    """
    Mirror Cloud Pak images to a private registry.
    
    Args:
        request: MirrorRequest containing registry configuration and entitlement key
        
    Returns:
        Status string indicating the mirror operation has started
    """
    # Request validation is handled by Pydantic model
    logger.debug(f"Mirror request - portable: {request.registry.portable}")
    logger.debug(f"Registry hostname: {request.registry.registryHostname}")
    logger.debug(f"Registry port: {request.registry.registryPort}")
    logger.debug(f"Registry namespace: {request.registry.registryNS}")
    logger.debug(f"Registry user: {request.registry.registryUser}")

    deployer_env = os.environ.copy()
    # Assemble the mirror command
    deploy_command = ['/cloud-pak-deployer/cp-deploy.sh']
    deploy_command += ['env', 'download']
    deploy_command += [f'-e=env_id={request.envId}']
    deploy_command += [f'-e=ibm_cp_entitlement_key={request.entitlementKey}']
    deploy_command += ['-v']
    
    process = subprocess.Popen(
        deploy_command,
        universal_newlines=True,
        env=deployer_env
    )

    return 'running'


def deploy(request: DeployRequest) -> DeployResponse:
    """
    Deploy Cloud Pak based on the running context.
    
    Args:
        request: DeployRequest containing deployment configuration
        
    Returns:
        DeployResponse with deployment status and details
    """
    deployer_env = os.environ.copy()
    deployer_env['envId'] = request.envId
    deployer_env['OCP_OC_LOGIN'] = request.oc_login_command
    deployer_env['CP_ENTITLEMENT_KEY'] = request.entitlementKey
    deployer_env['CONFIG_DIR'] = get_config_dir()
    deployer_env['STATUS_DIR'] = get_status_dir()
    
    if request.adminPassword is not None and request.adminPassword != '':
        deployer_env['adminPassword'] = request.adminPassword

    running_context = get_running_context()
    if running_context == 'local':
        result = deploy_local(deployer_env)
    else:
        result = deploy_openshift(deployer_env)

    return result


def deploy_local(deployer_env: Dict[str, str]) -> DeployResponse:
    """
    Start a local deployment process.
    
    Args:
        deployer_env: Environment variables for the deployment
        
    Returns:
        DeployResponse indicating the deployment has started
    """
    deploy_command = ['cp-deploy.sh', 'env']
    deploy_command += [f'-e=env_id={deployer_env["envId"]}']
    deploy_command += [f'-vs=oc-login={deployer_env["OCP_OC_LOGIN"]}']
    deploy_command += [f'-e=ibm_cp_entitlement_key={deployer_env["CP_ENTITLEMENT_KEY"]}']
    
    if 'adminPassword' in deployer_env and deployer_env['adminPassword'] != '':
        deploy_command += [f'-e=cp4d_admin_password={deployer_env["adminPassword"]}']
    
    deploy_command += ['-v']
    logger.debug(f'Deploy command: {deploy_command}')

    process = subprocess.Popen(
        deploy_command,
        universal_newlines=True,
        env=deployer_env
    )

    return DeployResponse(
        status='running',
        message='Deployment started successfully in local context'
    )


def deploy_openshift(deployer_env: Dict[str, str]) -> DeployResponse:
    """
    Start an OpenShift deployment by creating a Kubernetes Job.
    
    Args:
        deployer_env: Environment variables for the deployment
        
    Returns:
        DeployResponse indicating the job creation has started
    """
    deployer_dir = get_deployer_dir()
    deployer_start_file = f'{deployer_dir}/scripts/deployer/assets/cloud-pak-deployer-start.yaml'
    
    # Debug: Show content of deployer-start file
    try:
        with open(deployer_start_file, 'r') as f:
            deployer_start_content = f.read()
            logger.debug(f'Content of {deployer_start_file}:\n{deployer_start_content}')
    except Exception as e:
        logger.error(f'Failed to read deployer-start file: {e}')
    
    deploy_command = ['oc', 'create', '-f', deployer_start_file]
    logger.debug(f'Deploy command: {deploy_command}')

    process = subprocess.Popen(
        deploy_command,
        universal_newlines=True,
        env=deployer_env
    )

    return DeployResponse(
        status='running',
        message='Cloud Pak Deployer job creation initiated in OpenShift',
        job_name='cloud-pak-deployer'
    )


def delete_deployer_job() -> DeleteDeployerJobResponse:
    """
    Delete the Cloud Pak Deployer job in OpenShift.
    
    Only available for OpenShift deployments. Removes the deployer job
    and associated pods from the cluster.
    
    Returns:
        DeleteDeployerJobResponse with success status and message
        
    Raises:
        HTTPException: If running in local context or if deletion fails
    """
    running_context = get_running_context()
    deployer_project = get_deployer_project()
    
    if running_context == 'local':
        return DeleteDeployerJobResponse(
            success=False,
            message='Delete operation is only available for OpenShift deployments'
        )
    
    try:
        # Delete the cloud-pak-deployer job
        delete_job_command = [
            'oc', 'delete',
            f'-n={deployer_project}',
            'job', 'cloud-pak-deployer',
            '--ignore-not-found=true'
        ]
        logger.debug(f'Delete job command: {delete_job_command}')
        
        process = subprocess.Popen(
            delete_job_command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True
        )
        
        stdout, stderr = process.communicate()
        
        if process.returncode != 0:
            logger.error(f"Error deleting job: {stderr}")
            return DeleteDeployerJobResponse(
                success=False,
                message=f"Error deleting job: {stderr}"
            )
        
        logger.debug('Successfully deleted cloud-pak-deployer job and pods')
        return DeleteDeployerJobResponse(
            success=True,
            message='Cloud Pak Deployer job and related pods deleted successfully'
        )
        
    except Exception as e:
        logger.error(f"Exception while deleting deployer job: {str(e)}")
        return DeleteDeployerJobResponse(
            success=False,
            message=f"Exception: {str(e)}"
        )