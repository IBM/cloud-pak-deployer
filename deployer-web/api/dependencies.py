"""
Shared dependencies and configuration for Cloud Pak Deployer API.

This module contains global variables and configuration used across multiple services.
"""

import os
import logging
from pathlib import Path

# Configure logger
logger = logging.getLogger(__name__)

# Deployer directory and paths
deployer_dir = Path(os.path.dirname(os.path.realpath(__file__))).parent.parent
logger.info(f'Deployer directory: {deployer_dir}')

cp_base_config_path = os.path.join(deployer_dir, 'sample-configurations/sample-dynamic/config-samples')
ocp_base_config_path = os.path.join(deployer_dir, 'sample-configurations/sample-dynamic/config-samples')

# Runtime context
running_context = str(os.getenv('CPD_CONTEXT', default='local'))
logger.info(f'Deployer context: {running_context}')
logger.info(f'Logging level (CPD_WIZARD_LOG_LEVEL): {str(os.getenv("CPD_WIZARD_LOG_LEVEL", default="INFO"))}')

# OpenShift project/namespace
deployer_project = str(os.getenv('CPD_DEPLOYER_PROJECT', default='cloud-pak-deployer'))

# Configuration and status directories
config_dir = str(os.getenv('CONFIG_DIR'))
status_dir = str(os.getenv('STATUS_DIR'))


def get_deployer_dir() -> Path:
    """Get the deployer directory path."""
    return deployer_dir


def get_running_context() -> str:
    """Get the current running context ('local' or 'openshift')."""
    return running_context


def get_deployer_project() -> str:
    """Get the OpenShift deployer project/namespace name."""
    return deployer_project


def get_config_dir() -> str:
    """Get the configuration directory path."""
    return config_dir


def get_status_dir() -> str:
    """Get the status directory path."""
    return status_dir


def get_cp_base_config_path() -> str:
    """Get the Cloud Pak base configuration path."""
    return cp_base_config_path


def get_ocp_base_config_path() -> str:
    """Get the OpenShift base configuration path."""
    return ocp_base_config_path