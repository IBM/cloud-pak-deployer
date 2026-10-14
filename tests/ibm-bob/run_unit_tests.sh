#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# tests/ibm-bob/run_unit_tests.sh
#
# Unit and static tests: fast, no container, no cluster.
# Run from the repo root:
#   bash tests/ibm-bob/run_unit_tests.sh
#
# Requirements: python3 with python-benedict and pyyaml installed.
# Inside the deployer container these are already present.
# Outside the container, install with:
#   pip3 install python-benedict pyyaml
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== IBM Bob Unit Tests — preprocessor ==="
PYTHONPATH="${REPO_ROOT}/automation-roles/10-validation/lint-config/scripts" \
  python3 "${REPO_ROOT}/tests/ibm-bob/test_preprocessor.py" "$@"

echo "=== IBM Bob Unit Tests — variables & version table ==="
python3 "${REPO_ROOT}/tests/ibm-bob/test_variables.py" "$@"

echo "=== IBM Bob Unit Tests — config.yaml template rendering ==="
python3 "${REPO_ROOT}/tests/ibm-bob/test_template.py" "$@"

echo "=== All unit tests passed ==="
