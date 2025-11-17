#!/usr/bin/env python3
"""
Interactive helper for IBM Cloud Pak Deployer
"""
from __future__ import annotations

import json
import os
import shlex
import sys
from datetime import datetime
from getpass import getpass
from pathlib import Path
from typing import Any, Dict, List, Set


CATALOG_PATH = Path(__file__).with_name("service_catalog.json")
DEFAULT_BASE_DIR = Path.home() / "cloud-pak-deployer"
DEFAULT_CONFIG_SUBDIR = "configuration"
DEFAULT_STATUS_SUBDIR = "status"
DEFAULT_CONFIG_FILENAME = "cpd-config.yaml"
STATE_FILENAME = "helper-state.json"
DEFAULT_ENTITLEMENTS = [
    "cpd-enterprise",
    "cpd-standard",
    "cognos-analytics",
    "data-product-hub",
    "datastage",
    "data-integration-unstructured-data",
    "data-lineage",
    "ikc-premium",
    "ikc-standard",
    "openpages",
    "planning-analytics",
    "product-master",
    "speech-to-text",
    "text-to-speech",
    "watson-assistant",
    "watson-discovery",
    "watsonx-ai",
    "watsonx-code-assistant-ansible",
    "watsonx-code-assistant-z",
    "watsonx-data",
    "watsonx-gov-mm",
    "watsonx-gov-rc",
    "watsonx-orchestrate",
]


def load_catalog() -> List[Dict[str, Any]]:
    try:
        with CATALOG_PATH.open(encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as err:
        sys.exit(f"Unable to load service catalog: {err}")


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


def choose_services(catalog: List[Dict[str, Any]],
                    previous: List[str] | None = None) -> List[str]:
    required = {item["name"] for item in catalog if item.get("required")}
    optional = [item for item in catalog if item["name"] not in required]

    default_selected: Set[str] = set(previous or [])
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
    selected_optional: Set[str]
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


def choose_entitlements(previous: List[str] | None = None) -> List[str]:
    print("\nConfigure the CP4D entitlements. Select the subscriptions")
    print("that apply to your deployment.")
    current = previous or ["cpd-enterprise"]
    for idx, entitlement in enumerate(DEFAULT_ENTITLEMENTS, start=1):
        marker = "x" if entitlement in current else " "
        print(f"  {idx:>2}) [{marker}] {entitlement}")
    print("Enter comma-separated numbers to toggle entitlements.")
    print("Press Enter to keep the current values.")

    answer = prompt_text("Entitlements", default=None, required=False).strip().lower()
    if not answer:
        return current
    if answer == "all":
        return DEFAULT_ENTITLEMENTS.copy()
    if answer == "none":
        return []
    try:
        numbers = [int(part.strip()) for part in answer.split(",") if part.strip()]
    except ValueError:
        print("Invalid input, keeping current values.")
        return current

    selected = []
    for idx, entitlement in enumerate(DEFAULT_ENTITLEMENTS, start=1):
        if idx in numbers:
            selected.append(entitlement)
    if not selected:
        return current
    return selected


def build_cartridges(selected: List[str],
                     catalog: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    from copy import deepcopy

    selected_set = set(selected)
    cartridges: List[Dict[str, Any]] = []
    for item in catalog:
        template = deepcopy(item["template"])
        template["state"] = "installed" if item.get("required") or item["name"] in selected_set else "removed"
        cartridges.append(template)
    return cartridges


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
    storage_class = prompt_text("Default storage class", openshift_defaults.get("mcg", {}).get("storage_class",
                                                                                              "managed-nfs-storage"),
                                required=True)
    mcg_install = prompt_bool("Install OpenShift Data Foundation (MCG)?",
                              openshift_defaults.get("mcg", {}).get("install", False))

    cp4d_defaults = (defaults.get("cp4d") or [{}])[0]
    project = prompt_text("CP4D project/namespace", cp4d_defaults.get("project", "cpd"), required=True)
    operators_project = prompt_text("CP4D operators project", cp4d_defaults.get("operators_project", "cpd-operators"),
                                    required=True)
    cp4d_version = prompt_text("CP4D version (latest recommended)",
                               cp4d_defaults.get("cp4d_version", "latest"), required=True)
    accept_licenses = prompt_bool("Accept product licenses now?",
                                  cp4d_defaults.get("accept_licenses", True))
    production_license = prompt_bool("Use production licenses?",
                                     cp4d_defaults.get("cp4d_production_license", True))

    entitlements = choose_entitlements(cp4d_defaults.get("cp4d_entitlement"))
    catalog = load_catalog()
    selected_services = choose_services(catalog, state.get("selected_services"))

    oc_info = state.get("oc_info", {})
    api_url = prompt_text("OpenShift API URL", oc_info.get("api_url", "https://api.cluster.example.com:6443"),
                          required=True)
    oc_user = prompt_text("OpenShift admin user", oc_info.get("username", "kubeadmin"), required=True)
    oc_password = prompt_secret("OpenShift password or token", oc_info.get("password"))
    entitlement_key = prompt_secret("IBM Cloud entitlement key", state.get("entitlement_key"))

    cartridges = build_cartridges(selected_services, catalog)
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
        "cp4d": [
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
        ],
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

    state.update({
        "base_dir": str(base_dir),
        "config_dir": str(config_dir),
        "status_dir": str(status_dir),
        "config_filename": config_filename,
        "config": config_data,
        "selected_services": selected_services,
        "oc_info": {
            "api_url": api_url,
            "username": oc_user,
            "password": oc_password,
        },
        "entitlement_key": entitlement_key,
        "updated": datetime.utcnow().isoformat() + "Z",
    })
    write_file(state_path, json.dumps(state, indent=2) + "\n", secret=True)
    print(f"State stored at {state_path}")
    print("\nNext steps:")
    print(f"  1. Review {config_path} if needed.")
    print(f"  2. source {env_file_path}")
    print("  3. Run ./cp-deploy.sh env apply --accept-all-licenses")


if __name__ == "__main__":
    main()
