"""
Environment variable utilities for Cloud Pak Deployer.

This module provides functions for accessing and managing environment variables.
"""

import os
from typing import Dict


def get_environment_variables() -> Dict[str, str]:
    """
    Get relevant environment variables for the Cloud Pak Deployer wizard.
    
    Returns:
        Dictionary containing environment variable names and their values
    """
    result = {}
    
    result['CPD_WIZARD_PAGE_TITLE'] = os.getenv('CPD_WIZARD_PAGE_TITLE', default='Cloud Pak Deployer')
    result['CPD_WIZARD_MODE'] = os.getenv('CPD_WIZARD_MODE', default='')
    result['STATUS_DIR'] = os.getenv('STATUS_DIR', default='')
    result['CONFIG_DIR'] = os.getenv('CONFIG_DIR', default='')
    result['CPD_CONTEXT'] = os.getenv('CPD_CONTEXT', default='local')
    
    return result