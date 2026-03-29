"""
YAML utility functions for Cloud Pak Deployer.

This module provides utilities for loading, formatting, and sorting YAML configurations.
"""

import yaml
import logging

logger = logging.getLogger(__name__)


def load_yaml_file(path: str) -> dict:
    """
    Load a YAML file and return its contents as a dictionary.
    
    Supports multi-document YAML files by merging all documents into a single dictionary.
    
    Args:
        path: Path to the YAML file to load
        
    Returns:
        Dictionary containing the merged YAML content
        
    Raises:
        Exception: If the file cannot be read or parsed
    """
    result = {}
    content = ""
    try:
        with open(path, 'r', encoding='UTF-8') as f1:
            content = f1.read()
            docs = yaml.safe_load_all(content)
            for doc in docs:
                result = {**result, **doc}
    except Exception as e:
        logger.error(f'Error while reading file {path}: {e}')
        raise Exception(f'Error while reading file {path}')
    return result


def format_configuration_yaml(full_configuration: dict) -> str:
    """
    Format a configuration dictionary into a YAML string.
    
    Combines global_config, openshift, cp4d, and cp4i sections into a single YAML document.
    Applies special sorting for cp4d configurations.
    
    Args:
        full_configuration: Dictionary containing 'data' and 'metadata' sections
        
    Returns:
        Formatted YAML string with all configuration sections
    """
    global_config_yaml = yaml.safe_dump({'global_config': full_configuration['data']['global_config']})
    all_in_one = '---\n' + global_config_yaml

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
            cp4i_yaml = yaml.safe_dump({'cp4i': full_configuration['data']['cp4i']})
            all_in_one = all_in_one + '\n\n' + cp4i_yaml

    return all_in_one


def sort_cp4d_dict(items):
    """
    Sort cp4d dictionary items with specific key ordering.
    
    Sorting priority:
    1. project (if exists)
    2. operators_project (if exists)
    3. cp4d_version (if exists)
    4. Then by value type:
       - Scalars (str, int, float, bool, None)
       - Lists of scalars
       - Lists of dictionaries
       - Dictionaries
       
    Args:
        items: Dictionary items to sort (from dict.items())
        
    Returns:
        Sorted list of (key, value) tuples
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