#!/bin/bash
#
# Mirror images listed in an images-mapping.txt file from the source to the target registry using skopeo.
#
# Each non-empty, non-comment line of the mapping file must have the format:
#   <source-image>=<target-image>
# for example:
#   cp.icr.io/cp/cpd/foo@sha256:abc123...=registry.example.com:5000/cpd/foo:1.0.0
#
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

get_logtime() {
  echo $(date "+%Y-%m-%d %H:%M:%S")
}

log() {
  LOG_TIME=$(get_logtime)
  printf "[${LOG_TIME}] ${1}\n"
}

usage() {
  cat <<EOF
Usage: $0 -f <images-mapping.txt> [options]

Options:
  -f, --file <file>            images-mapping.txt file (mandatory)
  -s, --src-authfile <file>    Auth file (docker config.json/auth.json) for the source registry
  -d, --dest-authfile <file>   Auth file (docker config.json/auth.json) for the target registry
  -a, --authfile <file>        Auth file used for both source and target registry
  -p, --parallel <n>           Number of parallel copy processes (default: 1)
  -r, --retries <n>            Number of retries per image (default: 3)
      --src-tls-verify <bool>  Verify TLS of source registry (default: true)
      --dest-tls-verify <bool> Verify TLS of target registry (default: false)
      --all                    Copy all architectures of multi-arch images (default: skopeo default)
      --dry-run                Only show the skopeo commands, do not run them
  -h, --help                   Show this help
EOF
  exit 1
}

MAPPING_FILE=""
SRC_AUTHFILE=""
DEST_AUTHFILE=""
PARALLEL=1
RETRIES=3
SRC_TLS_VERIFY=true
DEST_TLS_VERIFY=false
COPY_ALL=false
DRY_RUN=false

while [[ $# -gt 0 ]];do
  case "$1" in
    -f|--file) MAPPING_FILE="$2"; shift 2;;
    -s|--src-authfile) SRC_AUTHFILE="$2"; shift 2;;
    -d|--dest-authfile) DEST_AUTHFILE="$2"; shift 2;;
    -a|--authfile) SRC_AUTHFILE="$2"; DEST_AUTHFILE="$2"; shift 2;;
    -p|--parallel) PARALLEL="$2"; shift 2;;
    -r|--retries) RETRIES="$2"; shift 2;;
    --src-tls-verify) SRC_TLS_VERIFY="$2"; shift 2;;
    --dest-tls-verify) DEST_TLS_VERIFY="$2"; shift 2;;
    --all) COPY_ALL=true; shift;;
    --dry-run) DRY_RUN=true; shift;;
    -h|--help) usage;;
    *) echo "Unknown option: $1"; usage;;
  esac
done

if [ -z "${MAPPING_FILE}" ];then
  usage
fi

if [ ! -f "${MAPPING_FILE}" ];then
  echo "Mapping file ${MAPPING_FILE} not found."
  exit 1
fi

if ! command -v skopeo >/dev/null 2>&1;then
  echo "skopeo command not found."
  exit 1
fi

if ! [[ "${PARALLEL}" =~ ^[1-9][0-9]*$ ]] || ! [[ "${RETRIES}" =~ ^[1-9][0-9]*$ ]];then
  echo "--parallel and --retries must be positive integers."
  exit 1
fi

for f in "${SRC_AUTHFILE}" "${DEST_AUTHFILE}";do
  if [ "${f}" != "" ] && [ ! -f "${f}" ];then
    echo "Auth file ${f} not found."
    exit 1
  fi
done

# Copy a single image; called as a function (exported for xargs) with "<source>=<target>" as argument
copy_image() {
  local line="$1"
  local src="${line%%=*}"
  local dest="${line#*=}"
  local skopeo_args=(copy --preserve-digests --retry-times 0
    --src-tls-verify="${SRC_TLS_VERIFY}" --dest-tls-verify="${DEST_TLS_VERIFY}")

  [ "${COPY_ALL}" == "true" ] && skopeo_args+=(--all)
  [ -n "${SRC_AUTHFILE}" ] && skopeo_args+=(--src-authfile "${SRC_AUTHFILE}")
  [ -n "${DEST_AUTHFILE}" ] && skopeo_args+=(--dest-authfile "${DEST_AUTHFILE}")
  skopeo_args+=("docker://${src}" "docker://${dest}")

  if [ "${DRY_RUN}" == "true" ];then
    log "skopeo ${skopeo_args[*]}"
    return 0
  fi

  local attempt
  for attempt in $(seq 1 ${RETRIES});do
    log "Copying ${src} to ${dest} (attempt ${attempt}/${RETRIES})"
    if skopeo "${skopeo_args[@]}" >/dev/null; then
      return 0
    fi
    [ ${attempt} -lt ${RETRIES} ] && sleep $((attempt * 5))
  done
  log "ERROR: failed to copy ${src} to ${dest}"
  return 1
}
export -f copy_image get_logtime log
export SRC_AUTHFILE DEST_AUTHFILE SRC_TLS_VERIFY DEST_TLS_VERIFY COPY_ALL DRY_RUN RETRIES

# Clean mapping file: strip comments, blank lines, carriage returns, and de-duplicate
work_dir=$(mktemp -d)
trap 'rm -rf "${work_dir}"' EXIT
sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "${MAPPING_FILE}" \
  | grep -v -e '^#' -e '^$' | awk '!seen[$0]++' > "${work_dir}/mapping.txt"

invalid=$(grep -vc '=' "${work_dir}/mapping.txt")
if [ "${invalid}" != "0" ];then
  echo "Mapping file contains ${invalid} line(s) without '=' separator:"
  grep -v '=' "${work_dir}/mapping.txt"
  exit 1
fi

total=$(wc -l < "${work_dir}/mapping.txt")
log "Mirroring ${total} images from ${MAPPING_FILE} (parallel: ${PARALLEL}, retries: ${RETRIES})"

# xargs returns non-zero if any invocation failed; failed lines are collected in the failed file
export FAILED_FILE="${work_dir}/failed.txt"
: > "${FAILED_FILE}"
tr '\n' '\0' < "${work_dir}/mapping.txt" \
  | xargs -0 -P "${PARALLEL}" -I{} bash -c 'copy_image "$1" || echo "$1" >> "${FAILED_FILE}"' _ {}

failed=$(wc -l < "${FAILED_FILE}")
if [ "${failed}" != "0" ];then
  log "ERROR: ${failed} of ${total} images failed to mirror:"
  cat "${FAILED_FILE}"
  exit 1
fi

log "Successfully mirrored ${total} images."
exit 0
