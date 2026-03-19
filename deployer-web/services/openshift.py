"""
OpenShift service for Cloud Pak Deployer.

This module handles OpenShift cluster operations including login and connection checks.
"""

import subprocess
import json
import re
import logging
from fastapi import HTTPException

from api.models import OcLoginRequest, OcCheckConnectionResponse

logger = logging.getLogger(__name__)


def oc_login(request: OcLoginRequest) -> dict:
    """
    Authenticate to an OpenShift cluster using the provided oc login command.
    
    Args:
        request: OcLoginRequest containing the oc login command
        
    Returns:
        Dictionary with code (0 for success) and optional error message
        
    Raises:
        HTTPException: If the command is not a valid oc login command
    """
    result = {
        "code": -1,
        "error": "",
    }
    
    oc_login_command = request.oc_login_command.strip()

    # Validate that it's an oc login command
    pattern = r'oc(\s+)login(\s)(.*)'
    is_oc_login_cmd = re.match(pattern, oc_login_command)
    
    if is_oc_login_cmd:
        proc = subprocess.Popen(
            oc_login_command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True
        )
        outputlog, errorlog = proc.communicate()

        if proc.returncode == 0:
            result["code"] = proc.returncode
            logger.info("Successfully logged in to OpenShift cluster")
        else:
            errors = str(errorlog, 'utf-8').split("\n")
            result = {"code": proc.returncode, "error": errors[-2]}
            logger.error(f'Login error: {errors}')

        return result
    else:
        raise HTTPException(status_code=400, detail='Bad Request: Invalid oc login command')


def oc_check_connection() -> OcCheckConnectionResponse:
    """
    Check the current OpenShift connection status and retrieve cluster information.
    
    Executes the following commands:
    1. oc whoami - Get current logged-in user
    2. oc whoami --show-server - Get OpenShift server URL
    3. oc version -o json - Get version information
    
    Returns:
        OcCheckConnectionResponse with connection status and cluster details
    """
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
            return OcCheckConnectionResponse(**result)
            
    except Exception as e:
        result["error"] = f"Error checking connection: {str(e)}"
        logger.error(f"Exception during oc whoami: {str(e)}")
        return OcCheckConnectionResponse(**result)
    
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
    
    return OcCheckConnectionResponse(**result)