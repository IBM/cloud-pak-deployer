#!/usr/bin/env bash
# ns-resources.sh – Show total CPU and memory requests/limits for a namespace

set -euo pipefail

ALL_NAMESPACES=false
NAMESPACE=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [NAMESPACE | -A]

Show total CPU and memory requests and limits for running pods.

Arguments:
  NAMESPACE             Namespace to inspect. Defaults to the current namespace.
  -A, --all-namespaces  Inspect all namespaces on worker/compute nodes only.
  -h, --help, -?        Show this help message.

A namespace-specific query includes pods running on control-plane/master nodes.
EOF
}

for arg in "$@"; do
  case "$arg" in
    -A|--all-namespaces) ALL_NAMESPACES=true ;;
    -h|--help|-\?) usage; exit 0 ;;
    *)  NAMESPACE="$arg" ;;
  esac
done

if $ALL_NAMESPACES; then
  NS_LABEL="All namespaces (compute nodes only)"
  OC_NS_FLAG="--all-namespaces"
else
  if [[ -z "$NAMESPACE" ]]; then
    NAMESPACE=$(oc config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
    if [[ -z "$NAMESPACE" ]]; then
      echo "Error: no namespace specified and no current namespace set in kubeconfig." >&2
      exit 1
    fi
  fi
  # Verify the namespace exists
  if ! oc get namespace "$NAMESPACE" &>/dev/null; then
    echo "Error: namespace '$NAMESPACE' not found." >&2
    exit 1
  fi
  NS_LABEL="$NAMESPACE"
  OC_NS_FLAG="-n $NAMESPACE"
fi

# Restrict all-namespaces results to worker nodes. Namespace-scoped results
# include every running pod, including pods scheduled on control-plane nodes.
if $ALL_NAMESPACES; then
  WORKER_NODES=$(oc get nodes -l node-role.kubernetes.io/worker \
    --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null | tr '\n' '|' | sed 's/|$//')
fi

# Collect all running containers' resource specs in one oc call (JSON).
# shellcheck disable=SC2086
POD_JSON=$(oc get pods $OC_NS_FLAG \
  --field-selector=status.phase=Running \
  -o json 2>/dev/null)

if $ALL_NAMESPACES; then
  POD_JSON=$(echo "$POD_JSON" | jq --arg workers "$WORKER_NODES" '
    .items |= map(select(.spec.nodeName | test("^(" + $workers + ")$")))
    | .
  ')
fi

# Convert CPU value to milli-cores (integer)
cpu_to_m() {
  local v="$1"
  if [[ -z "$v" || "$v" == "null" ]]; then echo 0; return; fi
  if [[ "$v" == *m ]]; then
    echo "${v%m}"
  else
    # plain cores → multiply by 1000
    echo $(( ${v%.*} * 1000 ))
  fi
}

# Convert memory value to MiB (integer)
mem_to_mi() {
  local v="$1"
  if [[ -z "$v" || "$v" == "null" ]]; then echo 0; return; fi
  if [[ "$v" == *Ki ]]; then echo $(( ${v%Ki} / 1024 ))
  elif [[ "$v" == *Mi ]]; then echo "${v%Mi}"
  elif [[ "$v" == *Gi ]]; then echo $(( ${v%Gi} * 1024 ))
  elif [[ "$v" == *Ti ]]; then echo $(( ${v%Ti} * 1024 * 1024 ))
  elif [[ "$v" == *k  ]]; then echo $(( ${v%k}  * 1000 / 1024 / 1024 ))
  elif [[ "$v" == *M  ]]; then echo $(( ${v%M}  / 1024 / 1024 * 1000000 ))
  elif [[ "$v" == *G  ]]; then echo $(( ${v%G}  * 1000 / 1024 ))
  else echo $(( v / 1024 / 1024 ))   # raw bytes
  fi
}

# Use jq to extract all resource values and sum them in awk
SUMS=$(echo "$POD_JSON" | jq -r '
  .items[].spec.containers[] |
  [
    (.resources.requests.cpu    // "0"),
    (.resources.requests.memory // "0"),
    (.resources.limits.cpu      // "0"),
    (.resources.limits.memory   // "0")
  ] | @tsv
')

req_cpu=0; req_mem=0; lim_cpu=0; lim_mem=0

while IFS=$'\t' read -r rc rm lc lm; do
  req_cpu=$(( req_cpu + $(cpu_to_m "$rc") ))
  req_mem=$(( req_mem + $(mem_to_mi "$rm") ))
  lim_cpu=$(( lim_cpu + $(cpu_to_m "$lc") ))
  lim_mem=$(( lim_mem + $(mem_to_mi "$lm") ))
done <<< "$SUMS"

# Format millicores → decimal CPUs (e.g. 1500m → 1.500)
fmt_cpu() { awk -v m="$1" 'BEGIN { printf "%.3f", m/1000 }'; }
# Format MiB → decimal GiB (e.g. 2048 MiB → 2.000 GiB)
fmt_mem() { awk -v mi="$1" 'BEGIN { printf "%.2f", mi/1024 }'; }

echo ""
echo "Namespace: $NS_LABEL"
# shellcheck disable=SC2086
echo "$(oc get pods $OC_NS_FLAG --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ') running pod(s)"
echo ""
printf "%-20s %12s %12s\n" ""              "CPU (cores)"  "Memory (GiB)"
printf "%-20s %12s %12s\n" "--------------------" "------------" "------------"
printf "%-20s %12s %12s\n" "Requests"      "$(fmt_cpu "$req_cpu")"  "$(fmt_mem "$req_mem")"
printf "%-20s %12s %12s\n" "Limits"        "$(fmt_cpu "$lim_cpu")"  "$(fmt_mem "$lim_mem")"
echo ""
