#!/usr/bin/env python3
"""
Interactive helper for IBM Cloud Pak Deployer
"""
from __future__ import annotations

import json
import os
import shlex
import sys
from copy import deepcopy
from datetime import datetime
from getpass import getpass
from pathlib import Path
from typing import Any, Dict, List, Tuple


CATALOG_PATH = Path(__file__).with_name("service_catalog.json")
DEFAULT_BASE_DIR = Path.home() / "cloud-pak-deployer"
DEFAULT_CONFIG_SUBDIR = "configuration"
DEFAULT_STATUS_SUBDIR = "status"
DEFAULT_CONFIG_FILENAME = "cpd-config.yaml"
STATE_FILENAME = "helper-state.json"


def load_catalog() -> List[Dict[str, Any]]:
    try:
        with CATALOG_PATH.open(encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError as err:
        sys.exit(f"Unable to load service catalog: {err}")
    profiles = data.get("profiles", [])
    if not profiles:
        sys.exit("No Cloud Pak profiles defined in service_catalog.json")
    return profiles


def prompt_text(message: str, default: str | None = None, required: bool = False,
                validator=None) -> str:
    while True:
        prompt = f"{message}"
        if default:
            prompt += f" [{default}]"
        prompt += ": "
        try:
            value = input(prompt).strip()
        except KeyboardInterrupt:
            print("\nAborted by user.")
            sys.exit(1)
        if not value:
            if default is not None:
                value = default
            elif required:
                print("Value is required.")
                continue
            else:
                return ""
        if validator:
            try:
                validator(value)
            except ValueError as exc:
                print(exc)
                continue
        return value


def prompt_bool(message: str, default: bool = True) -> bool:
    default_label = "Y/n" if default else "y/N"
    while True:
        answer = prompt_text(f"{message} ({default_label})", default=None, required=False).lower()
        if not answer:
            return default
        if answer in {"y", "yes"}:
            return True
        if answer in {"n", "no"}:
            return False
        print("Please answer with y or n.")


def prompt_secret(message: str, existing: str | None = None) -> str:
    prompt = message
    if existing:
        prompt += " (press Enter to keep existing value)"
    prompt += ": "
    while True:
        try:
            value = getpass(prompt)
        except KeyboardInterrupt:
            print("\nAborted by user.")
            sys.exit(1)
        if value:
            return value.strip()
        if existing:
            return existing
        print("A value is required.")


def ensure_directory(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def select_profile(profiles: List[Dict[str, Any]], previous_id: str | None) -> Dict[str, Any]:
    print("\nCloud Pak profiles available:")
    default_index = None
    for idx, profile in enumerate(profiles, start=1):
        marker = "*" if profile["id"] == previous_id else " "
        print(f"  {idx}){marker} {profile['name']}: {profile.get('description', '')}")
        if profile["id"] == previous_id:
            default_index = idx
    while True:
        default_value = str(default_index) if default_index else None
        answer = prompt_text("Select Cloud Pak profile", default_value, required=True)
        try:
            number = int(answer)
        except ValueError:
            print("Enter the number that matches the profile.")
            continue
        if 1 <= number <= len(profiles):
            return profiles[number - 1]
        print("Invalid selection.")


def choose_cp4d_cartridges(catalog: List[Dict[str, Any]],
                           previous: List[str] | None = None) -> List[str]:
    required = {item["name"] for item in catalog if item.get("required")}
    optional = [item for item in catalog if item["name"] not in required]

    default_selected = set(previous or [])
    if not default_selected:
        default_selected = {
            item["name"] for item in optional
            if item.get("default_state") == "installed"
        }

    print("\nSelect the Cloud Pak for Data cartridges to install.")
    print("Required cartridges are always installed.")
    for req_name in required:
        entry = next(item for item in catalog if item["name"] == req_name)
        print(f"  [required] {entry['name']} - {entry.get('description', '')}")

    print("\nOptional cartridges:")
    for idx, entry in enumerate(optional, start=1):
        marker = "x" if entry["name"] in default_selected else " "
        desc = entry.get("description", "")
        print(f"  {idx:>2}) [{marker}] {entry['name']} - {desc}")

    print("Enter comma-separated numbers (e.g. 1,3,5) to install those cartridges.")
    print("Type 'all' to install every optional cartridge, 'none' for minimum, or")
    print("press Enter to keep the current selection.")

    answer = prompt_text("Selection", default=None, required=False).strip().lower()
    selected_optional: set[str]
    if not answer:
        selected_optional = default_selected
    elif answer == "all":
        selected_optional = {item["name"] for item in optional}
    elif answer == "none":
        selected_optional = set()
    else:
        try:
            numbers = [int(part.strip()) for part in answer.split(",") if part.strip()]
        except ValueError:
            print("Invalid selection, keeping current values.")
            numbers = []
        selected_optional = set()
        for number in numbers:
            if 1 <= number <= len(optional):
                selected_optional.add(optional[number - 1]["name"])
            else:
                print(f"Ignoring unknown option {number}.")

    final_selection = set(required) | selected_optional
    return [entry["name"] for entry in catalog if entry["name"] in final_selection]


def choose_entitlements(available: List[str], previous: List[str] | None = None) -> List[str]:
    if not available:
        return []
    current = previous or ["cpd-enterprise"]
    print("\nConfigure the entitlements for your subscription.")
    for idx, entitlement in enumerate(available, start=1):
        marker = "x" if entitlement in current else " "
        print(f"  {idx:>2}) [{marker}] {entitlement}")
    print("Enter comma-separated numbers to toggle entitlements.")
    print("Type 'all' or 'none', or press Enter to keep the current values.")

    answer = prompt_text("Entitlements", default=None, required=False).strip().lower()
    if not answer:
        return current
    if answer == "all":
        return available.copy()
    if answer == "none":
        return []
    try:
        numbers = [int(part.strip()) for part in answer.split(",") if part.strip()]
    except ValueError:
        print("Invalid input, keeping current values.")
        return current

    selected = []
    for idx, entitlement in enumerate(available, start=1):
        if idx in numbers:
            selected.append(entitlement)
    if not selected:
        return current
    return selected


def build_cartridges(selected: List[str],
                     catalog: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    selected_set = set(selected)
    cartridges: List[Dict[str, Any]] = []
    for item in catalog:
        template = deepcopy(item["template"])
        template["state"] = "installed" if item.get("required") or item["name"] in selected_set else "removed"
        cartridges.append(template)
    return cartridges


def choose_cp4ba_patterns(profile: Dict[str, Any], previous: Dict[str, bool] | None = None) -> Dict[str, bool]:
    selections: Dict[str, bool] = {}
    prev = previous or {}
    print("\nCloud Pak for Business Automation patterns:")
    for pattern in profile.get("patterns", []):
        pattern_id = pattern["id"]
        if pattern.get("required"):
            selections[pattern_id] = True
            print(f"  [required] {pattern['label']}")
            continue
        default = prev.get(pattern_id, pattern.get("default", True))
        selections[pattern_id] = prompt_bool(f"Enable {pattern['label']}?", default)
    return selections


def choose_cp4ba_addons(profile: Dict[str, Any], previous: Dict[str, bool] | None = None) -> Dict[str, bool]:
    selections: Dict[str, bool] = {}
    prev = previous or {}
    if not profile.get("addons"):
        return selections
    print("\nAdditional services and accelerators:")
    for addon in profile["addons"]:
        default = prev.get(addon["id"], addon.get("default", True))
        selections[addon["id"]] = prompt_bool(f"Enable {addon['label']}?", default)
    return selections


def choose_cp4i_instances(instances: List[Dict[str, Any]],
                          previous: List[str] | None = None) -> Tuple[List[str], List[Dict[str, Any]]]:
    required_ids = [item["id"] for item in instances if item.get("required")]
    optional = [item for item in instances if item["id"] not in required_ids]
    default_selected = set(previous or [])
    if not default_selected:
        default_selected = {item["id"] for item in optional if item.get("default")}

    print("\nSelect the Cloud Pak for Integration instances to create.")
    for req_id in required_ids:
        entry = next(item for item in instances if item["id"] == req_id)
        print(f"  [required] {entry['label']}")

    if optional:
        print("\nOptional instances:")
        for idx, entry in enumerate(optional, start=1):
            marker = "x" if entry["id"] in default_selected else " "
            print(f"  {idx:>2}) [{marker}] {entry['label']}")
        print("Enter comma-separated numbers to enable optional instances (Enter to keep current values).")

        answer = prompt_text("Instances", default=None, required=False).strip().lower()
        selected_optional: set[str]
        if not answer:
            selected_optional = default_selected
        elif answer == "all":
            selected_optional = {item["id"] for item in optional}
        elif answer == "none":
            selected_optional = set()
        else:
            try:
                numbers = [int(part.strip()) for part in answer.split(",") if part.strip()]
            except ValueError:
                print("Invalid selection, keeping current values.")
                numbers = []
            selected_optional = set()
            for number in numbers:
                if 1 <= number <= len(optional):
                    selected_optional.add(optional[number - 1]["id"])
                else:
                    print(f"Ignoring unknown option {number}.")
    else:
        selected_optional = set()

    selected_ids = set(required_ids) | selected_optional
    ordered_ids = [item["id"] for item in instances if item["id"] in selected_ids]
    payload = [deepcopy(item["template"]) for item in instances if item["id"] in selected_ids]
    return ordered_ids, payload


def build_cp4d_section(profile: Dict[str, Any],
                       stored_config: Dict[str, Any],
                       profile_state: Dict[str, Any]) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
    defaults = stored_config or {}
    previous_state = profile_state or {}
    project = prompt_text("CP4D project/namespace", defaults.get("project", "cpd"), required=True)
    operators_project = prompt_text("CP4D operators project", defaults.get("operators_project", "cpd-operators"),
                                    required=True)
    cp4d_version = prompt_text("CP4D version (latest recommended)",
                               defaults.get("cp4d_version", "latest"), required=True)
    accept_licenses = prompt_bool("Accept product licenses now?",
                                  defaults.get("accept_licenses", True))
    production_license = prompt_bool("Use production licenses?",
                                     defaults.get("cp4d_production_license", True))
    entitlements = choose_entitlements(profile.get("entitlements", []),
                                       previous_state.get("entitlements") or defaults.get("cp4d_entitlement"))
    selected_services = choose_cp4d_cartridges(profile.get("cartridges", []),
                                               previous_state.get("selected_services"))
    cartridges = build_cartridges(selected_services, profile.get("cartridges", []))
    payload = [
        {
            "project": project,
            "openshift_cluster_name": "{{ env_id }}",
            "cp4d_version": cp4d_version,
            "cp4d_entitlement": entitlements,
            "cp4d_production_license": production_license,
            "accept_licenses": accept_licenses,
            "db2u_limited_privileges": False,
            "use_fs_iam": True,
            "operators_project": operators_project,
            "ibm_cert_manager": False,
            "install_day0_patch": True,
            "state": "installed",
            "cartridges": cartridges,
        }
    ]
    return payload, {
        "selected_services": selected_services,
        "entitlements": entitlements,
        "project": project,
        "operators_project": operators_project,
        "cp4d_version": cp4d_version,
    }


def build_cp4ba_patterns(toggle: Dict[str, bool]) -> Dict[str, Any]:
    return {
        "foundation": {
            "optional_components": {
                "bas": True,
                "bai": True,
                "ae": True,
            }
        },
        "decisions": {
            "enabled": toggle.get("decisions", True),
            "optional_components": {
                "decision_center": True,
                "decision_runner": True,
                "decision_server_runtime": True,
            },
            "cr_custom": {
                "spec": {
                    "odm_configuration": {
                        "decisionCenter": {
                            "disabledDecisionModel": False
                        }
                    }
                }
            }
        },
        "decisions_ads": {
            "enabled": toggle.get("decisions_ads", True),
            "optional_components": {
                "ads_designer": True,
                "ads_runtime": True,
            },
            "gen_ai": {
                "apiKey": "watsonx_ai_api_key",
                "mlUrl": "https://us-south.ml.cloud.ibm.com",
                "projectId": "project_id",
            }
        },
        "content": {
            "enabled": toggle.get("content", True),
            "optional_components": {
                "cmis": True,
                "css": True,
                "es": True,
                "tm": True,
                "ier": True,
                "icc4sap": False,
            }
        },
        "application": {
            "enabled": toggle.get("application", True),
            "optional_components": {
                "app_designer": True,
                "ae_data_persistence": True,
            }
        },
        "document_processing": {
            "enabled": toggle.get("document_processing", True),
            "optional_components": {
                "document_processing_designer": True,
            },
            "cr_custom": {
                "spec": {
                    "ca_configuration": {
                        "ocrextraction": {
                            "use_iocr": "auto",
                            "deep_learning_object_detection": {
                                "enabled": True
                            }
                        },
                        "deeplearning": {
                            "gpu_enabled": False,
                            "nodelabel_key": "nvidia.com/gpu.present",
                            "nodelabel_value": "true",
                            "replica_count": 1,
                        }
                    }
                }
            }
        },
        "workflow": {
            "enabled": toggle.get("workflow", True),
            "optional_components": {
                "baw_authoring": True,
                "kafka": True,
            },
            "gen_ai": {
                "apiKey": "watsonx_ai_api_key",
                "mlUrl": "https://us-south.ml.cloud.ibm.com",
                "projectId": "project_id",
                "defaultFoundationModel": "meta-llama/llama-3-3-70b-instruct",
            }
        },
    }


def build_cp4ba_section(profile: Dict[str, Any],
                        stored_config: Dict[str, Any],
                        profile_state: Dict[str, Any],
                        context: Dict[str, Any]) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
    defaults = profile.get("defaults", {})
    existing = stored_config or {}
    previous_state = profile_state or {}
    project = prompt_text("CP4BA project/namespace", existing.get("project", defaults.get("project", "cp4ba")),
                          required=True)
    collateral_project = prompt_text("CP4BA collateral project",
                                     existing.get("collateral_project", defaults.get("collateral_project",
                                                                                      "cp4ba-collateral")),
                                     required=True)
    storage_name = prompt_text("CP4BA storage class",
                               existing.get("openshift_storage_name",
                                            defaults.get("openshift_storage_name",
                                                         context.get("storage_class", "auto-storage"))),
                               required=True)
    accept_licenses = prompt_bool("Accept CP4BA licenses now?",
                                  existing.get("accept_licenses", False))
    cpfs_profile = prompt_text("Foundational services profile size",
                               existing.get("cpfs_profile_size", defaults.get("cpfs_profile_size", "small")),
                               required=True)
    cp4ba_profile_size = prompt_text("CP4BA profile size",
                                     existing.get("cp4ba", {}).get("profile_size",
                                                                   defaults.get("profile_size", "small")),
                                     required=True)

    pattern_state = choose_cp4ba_patterns(profile, previous_state.get("patterns"))
    addon_state = choose_cp4ba_addons(profile, previous_state.get("addons"))

    pm_enabled = addon_state.get("pm", True)
    rpa_enabled = addon_state.get("rpa", True)

    payload = [
        {
            "project": project,
            "collateral_project": collateral_project,
            "openshift_cluster_name": "{{ env_id }}",
            "openshift_storage_name": storage_name,
            "accept_licenses": accept_licenses,
            "state": "installed",
            "cpfs_profile_size": cpfs_profile,
            "cp4ba": {
                "enabled": True,
                "profile_size": cp4ba_profile_size,
                "patterns": build_cp4ba_patterns(pattern_state),
            },
            "pm": {
                "enabled": pm_enabled,
                "cr_custom": {
                    "spec": {
                        "processmining": {
                            "storage": {
                                "redis": {
                                    "install": False
                                }
                            }
                        }
                    }
                }
            },
            "rpa": {
                "enabled": rpa_enabled,
                "cr_custom": {
                    "spec": {
                        "nlp": {
                            "replicas": 1
                        }
                    }
                }
            },
            "cloudbeaver_enabled": addon_state.get("cloudbeaver_enabled", True),
            "roundcube_enabled": addon_state.get("roundcube_enabled", True),
            "cerebro_enabled": addon_state.get("cerebro_enabled", True),
            "akhq_enabled": addon_state.get("akhq_enabled", True),
            "mongo_express_enabled": addon_state.get("mongo_express_enabled", True),
            "phpldapadmin_enabled": addon_state.get("phpldapadmin_enabled", True),
            "opensearch_dashboards_enabled": addon_state.get("opensearch_dashboards_enabled", True),
        }
    ]
    return payload, {
        "project": project,
        "collateral_project": collateral_project,
        "patterns": pattern_state,
        "addons": addon_state,
        "cpfs_profile_size": cpfs_profile,
        "profile_size": cp4ba_profile_size,
    }


def build_cp4i_section(profile: Dict[str, Any],
                       stored_config: Dict[str, Any],
                       profile_state: Dict[str, Any],
                       context: Dict[str, Any]) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
    defaults = profile.get("defaults", {})
    existing = stored_config or {}
    previous_state = profile_state or {}
    project = prompt_text("CP4I project/namespace", existing.get("project", defaults.get("project", "cp4i")),
                          required=True)
    storage_name = prompt_text("CP4I storage class", existing.get("openshift_storage_name",
                                                                  defaults.get("openshift_storage_name",
                                                                               context.get("storage_class",
                                                                                           "managed-nfs-storage"))),
                               required=True)
    cp4i_version = prompt_text("CP4I version", existing.get("cp4i_version", defaults.get("cp4i_version",
                                                                                         "2021.4.1")), required=True)
    use_case_files = prompt_bool("Use CASE files?", existing.get("use_case_files", defaults.get("use_case_files", True)))
    accept_licenses = prompt_bool("Accept CP4I licenses now?",
                                  existing.get("accept_licenses", defaults.get("accept_licenses", False)))
    use_top_level_operator = prompt_bool("Use top-level operator?",
                                         existing.get("use_top_level_operator",
                                                      defaults.get("use_top_level_operator", False)))
    top_level_channel = existing.get("top_level_operator_channel",
                                     defaults.get("top_level_operator_channel", "v1.5"))
    top_level_case = existing.get("top_level_operator_case_version",
                                  defaults.get("top_level_operator_case_version", "2.5.0"))
    if use_top_level_operator:
        top_level_channel = prompt_text("Top-level operator channel", top_level_channel, required=True)
        top_level_case = prompt_text("Top-level operator CASE version", top_level_case, required=True)

    operators_all_namespaces = prompt_bool("Install operators cluster-wide?",
                                           existing.get("operators_in_all_namespaces",
                                                        defaults.get("operators_in_all_namespaces", True)))

    selected_ids, instances_payload = choose_cp4i_instances(profile.get("instances", []),
                                                            previous_state.get("selected_instances"))

    entry: Dict[str, Any] = {
        "project": project,
        "openshift_cluster_name": "{{ env_id }}",
        "openshift_storage_name": storage_name,
        "cp4i_version": cp4i_version,
        "use_case_files": use_case_files,
        "accept_licenses": accept_licenses,
        "use_top_level_operator": use_top_level_operator,
        "operators_in_all_namespaces": operators_all_namespaces,
        "instances": instances_payload,
    }
    if use_top_level_operator:
        entry["top_level_operator_channel"] = top_level_channel
        entry["top_level_operator_case_version"] = top_level_case

    return [entry], {
        "project": project,
        "storage_name": storage_name,
        "cp4i_version": cp4i_version,
        "selected_instances": selected_ids,
    }


def build_profile_section(profile: Dict[str, Any],
                          stored_config: Dict[str, Any],
                          profile_state: Dict[str, Any],
                          context: Dict[str, Any]) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
    profile_type = profile.get("type")
    if profile_type == "cp4d":
        return build_cp4d_section(profile, stored_config, profile_state)
    if profile_type == "cp4ba":
        return build_cp4ba_section(profile, stored_config, profile_state, context)
    if profile_type == "cp4i":
        return build_cp4i_section(profile, stored_config, profile_state, context)
    raise ValueError(f"Unsupported profile type: {profile_type}")


def format_yaml(data: Any, indent: int = 0) -> str:
    indent_str = "  " * indent
    if isinstance(data, dict):
        lines = []
        for key, value in data.items():
            if isinstance(value, (dict, list)):
                lines.append(f"{indent_str}{key}:")
                nested = format_yaml(value, indent + 1)
                if nested:
                    lines.append(nested)
            else:
                lines.append(f"{indent_str}{key}: {json.dumps(value)}")
        return "\n".join(lines)
    if isinstance(data, list):
        if not data:
            return indent_str + "[]"
        lines = []
        for value in data:
            if isinstance(value, (dict, list)):
                lines.append(f"{indent_str}-")
                lines.append(format_yaml(value, indent + 1))
            else:
                lines.append(f"{indent_str}- {json.dumps(value)}")
        return "\n".join(lines)
    return indent_str + json.dumps(data)


def write_file(path: Path, content: str, secret: bool = False) -> None:
    ensure_directory(path.parent)
    path.write_text(content, encoding="utf-8")
    if secret:
        os.chmod(path, 0o600)


def write_env_file(path: Path, config_dir: Path, status_dir: Path,
                   env_id: str, oc_info: Dict[str, str], entitlement_key: str) -> None:
    lines = [
        "#!/usr/bin/env bash",
        "# Generated by cp-deploy helper - contains sensitive values",
        f"export CONFIG_DIR={shlex.quote(str(config_dir))}",
        f"export STATUS_DIR={shlex.quote(str(status_dir))}",
        f"export CPD_ENV_ID={shlex.quote(env_id)}",
    ]
    if oc_info.get("api_url"):
        lines.append(f"export OCP_API_URL={shlex.quote(oc_info['api_url'])}")
    if oc_info.get("username"):
        lines.append(f"export OCP_USERNAME={shlex.quote(oc_info['username'])}")
    if oc_info.get("password"):
        lines.append(f"export OCP_PASSWORD={shlex.quote(oc_info['password'])}")
    if entitlement_key:
        lines.append(f"export IBM_CP_ENTITLEMENT_KEY={shlex.quote(entitlement_key)}")
    lines.append('echo "Environment variables loaded for Cloud Pak Deployer."')
    lines.append('echo "Remember to login with: oc login $OCP_API_URL -u $OCP_USERNAME"')
    script = "\n".join(lines) + "\n"
    write_file(path, script, secret=True)


def main() -> None:
    print("=" * 72)
    print("IBM Cloud Pak Deployer helper")
    print("=" * 72)

    profiles = load_catalog()

    default_base = Path(os.environ.get("CPD_HELPER_HOME", DEFAULT_BASE_DIR))
    base_dir = Path(prompt_text("Helper workspace directory", str(default_base), required=True)).expanduser()

    state_path = base_dir / STATE_FILENAME
    state: Dict[str, Any] = {}
    if state_path.exists():
        try:
            with state_path.open(encoding="utf-8") as handle:
                state = json.load(handle)
            print(f"Loaded existing helper state from {state_path}")
        except json.JSONDecodeError:
            print("Could not parse existing helper state, starting fresh.")

    profile = select_profile(profiles, state.get("selected_profile"))
    profile_states = state.get("profiles_state", {})
    profile_state = profile_states.get(profile["id"], {})

    default_config_dir = state.get("config_dir") or str(base_dir / DEFAULT_CONFIG_SUBDIR)
    default_status_dir = state.get("status_dir") or str(base_dir / DEFAULT_STATUS_SUBDIR)
    config_dir = Path(prompt_text("CONFIG_DIR path", default_config_dir, required=True)).expanduser()
    status_dir = Path(prompt_text("STATUS_DIR path", default_status_dir, required=True)).expanduser()
    ensure_directory(config_dir)
    ensure_directory(config_dir / "config")
    ensure_directory(status_dir)

    defaults = state.get("config", {})
    global_defaults = defaults.get("global_config", {})
    env_name = prompt_text("Environment name", global_defaults.get("environment_name", "sample"), required=True)
    env_id = prompt_text("Environment ID", global_defaults.get("env_id", "cpd-env"), required=True)
    cloud_platform = prompt_text("Cloud platform (existing-ocp, ibm-cloud, aws-rosa, azure-aro)",
                                 global_defaults.get("cloud_platform", "existing-ocp"), required=True)
    confirm_destroy = prompt_bool("Require confirmation before destroy?",
                                  global_defaults.get("confirm_destroy", False))
    optimize_deploy = prompt_bool("Enable deploy optimization?",
                                  global_defaults.get("optimize_deploy", True))

    openshift_defaults = (defaults.get("openshift") or [{}])[0]
    ocp_version = prompt_text("OpenShift version", openshift_defaults.get("ocp_version", "4.16"), required=True)
    cluster_name = prompt_text("Cluster name", openshift_defaults.get("cluster_name", env_id), required=True)
    domain_name = prompt_text("Cluster domain name", openshift_defaults.get("domain_name", "example.com"),
                              required=True)
    storage_class = prompt_text("Default storage class",
                                openshift_defaults.get("mcg", {}).get("storage_class", "managed-nfs-storage"),
                                required=True)
    mcg_install = prompt_bool("Install OpenShift Data Foundation (MCG)?",
                              openshift_defaults.get("mcg", {}).get("install", False))

    oc_info = state.get("oc_info", {})
    api_url = prompt_text("OpenShift API URL", oc_info.get("api_url", "https://api.cluster.example.com:6443"),
                          required=True)
    oc_user = prompt_text("OpenShift admin user", oc_info.get("username", "kubeadmin"), required=True)
    oc_password = prompt_secret("OpenShift password or token", oc_info.get("password"))
    entitlement_key = prompt_secret("IBM Cloud entitlement key", state.get("entitlement_key"))

    stored_profile_config = (defaults.get(profile["id"]) or [{}])
    stored_profile_entry = stored_profile_config[0] if stored_profile_config else {}
    context = {"storage_class": storage_class}
    profile_payload, profile_state_update = build_profile_section(profile, stored_profile_entry,
                                                                  profile_state, context)

    config_data: Dict[str, Any] = {
        "global_config": {
            "environment_name": env_name,
            "cloud_platform": cloud_platform,
            "env_id": env_id,
            "confirm_destroy": confirm_destroy,
            "optimize_deploy": optimize_deploy,
        },
        "openshift": [
            {
                "name": "{{ env_id }}",
                "ocp_version": ocp_version,
                "cluster_name": cluster_name,
                "domain_name": domain_name,
                "mcg": {
                    "install": mcg_install,
                    "storage_type": "storage-class",
                    "storage_class": storage_class,
                },
                "gpu": {
                    "install": "auto",
                },
                "openshift_ai": {
                    "install": "auto",
                    "channel": "auto",
                },
                "openshift_storage": [
                    {
                        "storage_name": "auto-storage",
                        "storage_type": "auto",
                    }
                ],
            }
        ],
        profile["id"]: profile_payload,
    }

    yaml_content = "---\n" + format_yaml(config_data) + "\n"
    config_filename = state.get("config_filename", DEFAULT_CONFIG_FILENAME)
    config_path = config_dir / "config" / config_filename
    write_file(config_path, yaml_content, secret=False)
    print(f"\nConfiguration file written to {config_path}")

    env_file_path = base_dir / "set-env.sh"
    write_env_file(env_file_path, config_dir, status_dir, env_id,
                   {"api_url": api_url, "username": oc_user, "password": oc_password},
                   entitlement_key)
    print(f"Environment file created at {env_file_path} (contains sensitive data).")

    profile_states[profile["id"]] = profile_state_update
    state.update({
        "base_dir": str(base_dir),
        "config_dir": str(config_dir),
        "status_dir": str(status_dir),
        "config_filename": config_filename,
        "config": config_data,
        "profiles_state": profile_states,
        "selected_profile": profile["id"],
        "oc_info": {
            "api_url": api_url,
            "username": oc_user,
            "password": oc_password,
        },
        "entitlement_key": entitlement_key,
        "updated": datetime.utcnow().isoformat() + "Z",
    })
    if profile["id"] == "cp4d":
        state["selected_services"] = profile_state_update.get("selected_services", [])
    write_file(state_path, json.dumps(state, indent=2) + "\n", secret=True)
    print(f"State stored at {state_path}")
    print("\nNext steps:")
    print(f"  1. Review {config_path} if needed.")
    print(f"  2. source {env_file_path}")
    print("  3. Run ./cp-deploy.sh env apply --accept-all-licenses")


if __name__ == "__main__":
    main()
