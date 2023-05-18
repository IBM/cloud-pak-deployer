#!/bin/bash

# ---------- Command arguments ----------

# the CASE archive directory
CASE_ARCHIVE_DIR=

# the CASE archive name
CASE_ARCHIVE=

# dry-run mode
DRY_RUN=

# source image
IMAGE=

# image CSV file
IMAGE_CSV_FILE=

# the source image registry
SOURCE_REGISTRY=

# the target image registry
TARGET_REGISTRY=

# Boolean toggle to determine if the command called was for mirroring images or not
IMAGE_MIRROR_ACTION_CALLED=

# ---------- Command variables ----------

# data path that keeps the registry authentication secrets
AUTH_DATA_PATH="${XDG_RUNTIME_DIR}/containers"

# namespace action for image mirroring
NAMESPACE_ACTION=

# namespace action value for image mirroring
NAMESPACE_ACTION_VALUE=

# temporary file prefix
OC_TMP_PREFIX="airgap"

# temporary image mapping file split size
OC_TMP_IMAGE_MAP_SPLIT_SIZE=20

# script directory
SCRIPT_DIR=`dirname "$0"`

# defaut log dir
LOG_DIR="/tmp"

# script version
VERSION=0.0.2

# --- registry service variables ---

# container engine used to run the registry, either 'docker' or 'podman'
CONTAINER_ENGINE=

# auth.json file
AUTH_JSON=/tmp/auth.json

# indicates if registry is TLS enabled
REGISTRY_TLS_ENABLED=true

# ---------- Shared Package Variables ----------
# Context of mirrored image CSV files created
declare -a MIRRORED_IMAGE_CSV_CONTEXT=


# ---------- Command functions ----------

#
# Main function
#
main() {
    # parses command arguments
    parse_arguments "$@"
}

#
# Parses the CLI arguments
#
parse_arguments() {
    if [[ "$#" == 0 ]]; then
        print_usage
        exit 1
    fi

    # process options
    while [[ "$1" != "" ]]; do
        case "$1" in
        image)
            shift
            parse_image_arguments "$@"
            break
            ;;
        -v | --version)
            print_version
            exit 1
            ;;       
        -h | --help)
            print_usage
            exit 1
            ;;
        *)
            print_usage
            exit 1
            ;;
        esac
        shift
    done
}

#
# Prints usage menu
#
print_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} [registry|image|cluster]"
    echo ""
    echo "This tool helps mirroring CASE images to support"
    echo "installing IBM Cloud Pak in an Air-Gapped environment"
    echo ""
    echo "Options:"
    echo "   image             Mirroring images from one registry to another"
    echo "   -v, --version     Print version information"
    echo "   -h, --help        Print usage information"
    echo ""
}

#
# Prints version 
#
print_version() {
    echo "[INFO] Version ${VERSION}"
}

# ---------- Image mirror functions ----------

#
# Handles 'image mirror' action
#
do_image_mirror() {
    # parses arguments
    parse_image_mirror_arguments "$@"

    # temporary image mapping file
    START_EPOCH=$(date +%s)
    CUR_TS=$(date "+%Y%m%d%H%M%S")
    OC_TMP_DIR=${LOG_DIR}/${OC_TMP_PREFIX}_image_mapping_${CUR_TS}
    mkdir -p ${OC_TMP_DIR}
    OC_TMP_IMAGE_MAP=${OC_TMP_DIR}/airgap_image_mapping
    
    # validates arguments
    validate_image_mirror_arguments

    # verifies if target registry is SSL enabeld
    if [[ ! -z "$(curl -I -k https://${TARGET_REGISTRY} --connect-timeout 5 2>/dev/null | grep '200')" ]]; then
        REGISTRY_TLS_ENABLED=false
    fi

    # Process case files and mirror images
    process_case_archive_dir
    generate_image_mapping_file
    if [ ! -z "${USE_SKOPEO}" ]; then
        do_skopeo_copy_case_images
    else
        do_image_mirror_case_images
    fi
    tag_latest_olm_catalog_images
    END_EPOCH=$(date +%s)
    MIRROR_SECS=$((END_EPOCH - START_EPOCH))
    printf 'Mirroring completed after %dh:%dm:%ds\n' $((MIRROR_SECS/3600)) $((MIRROR_SECS%3600/60)) $((MIRROR_SECS%60))
}


#
# Uses `oc image mirror` command to mirror the CASE images
# 
do_image_mirror_case_images() {
    if [ ! -f "${OC_TMP_IMAGE_MAP}" ]; then
        echo "[ERROR] No image mapping found"
        exit 11
    fi

    # replace the original registry with the specified source registry
    if [  ! -z "${SOURCE_REGISTRY}" ]; then
        cat ${OC_TMP_IMAGE_MAP} | sed -e "s/[^\/]*/${SOURCE_REGISTRY}/" 1<> "${OC_TMP_IMAGE_MAP}"
    fi

    echo "[INFO] Start mirroring CASE images ..."
    
    images_count=$(wc -l "${OC_TMP_IMAGE_MAP}" | awk '{ print $1 }')
    map_files="${OC_TMP_IMAGE_MAP}"

    echo "[INFO] Total image count: ${images_count}"

    # Remove ppc64le and s390x images
    # sed -i "/ppc64le/d" ${OC_TMP_IMAGE_MAP}
    # sed -i "/x390x/d" ${OC_TMP_IMAGE_MAP}
    images_count=$(wc -l "${OC_TMP_IMAGE_MAP}" | awk '{ print $1 }')

    echo "[INFO] Found ${images_count} images after filtering"

    # images_count=$(wc -l "${OC_TMP_IMAGE_MAP}" | awk '{ print $1 }')

    if [[ "${OC_TMP_IMAGE_MAP_SPLIT_SIZE}" -gt 0 ]] && [[ ${images_count} -gt ${OC_TMP_IMAGE_MAP_SPLIT_SIZE} ]]; then
        # splitting the image map into multiple files
        mkdir -p "${OC_TMP_IMAGE_MAP}_splits"
        split -l ${OC_TMP_IMAGE_MAP_SPLIT_SIZE} ${OC_TMP_IMAGE_MAP} ${OC_TMP_IMAGE_MAP}_splits/image_map_
        map_files=$(find "${OC_TMP_IMAGE_MAP}_splits" -name "image_map_*")
    fi

    for map_file in ${map_files}; do
        echo "[INFO] Mirroring ${map_file}"
        echo "[STATE] Total image count: ${images_count}"
        current_image=$(head -1 ${map_file} | cut -d= -f1)
        echo "[STATE] Current image: ${current_image}"
        image_number=$(grep -n ${current_image} ${OC_TMP_IMAGE_MAP} | cut -d: -f1)
        echo "[STATE] Image number: ${image_number}"
        oc_cmd="time oc image mirror -a ${AUTH_JSON} -f \"${map_file}\" --filter-by-os '.*' --insecure ${DRY_RUN}"
        echo "${oc_cmd}"
        eval ${oc_cmd}

        mirror_exit=$?

        if [[ "$mirror_exit" -ne 0 ]]; then

            echo "[INFO] Start mirroring CASE images using skopeo ..."

            while read in; do
                src_image=$(echo $in | cut -d= -f1)
                tgt_image=$(echo $in | cut -d= -f2)
                current_image=${src_image}
                echo "[STATE] Current image: ${current_image}"
                image_number=$(grep -n ${current_image} ${OC_TMP_IMAGE_MAP})
                echo "[STATE] Image number: ${image_number}"                
                skopeo_cmd="skopeo copy --all --authfile ${AUTH_JSON} --dest-tls-verify=false --src-tls-verify=false docker://${src_image} docker://${tgt_image}" ;
                echo "${skopeo_cmd}"
                eval ${skopeo_cmd}

                if [[ "$?" -ne 0 ]]; then
                    # On error we need to clean up our mirrored csv file
                    cleanup_mirrored_csv_files_from_current_run

                    exit 11
                fi
            done < ${map_file}
        fi
    done
    echo "[STATE] Image number: ${images_count}"
    echo "[STATE] Finished mirroring images"

}

#
# Uses `skopeo copy` command to mirror the CASE images
#
do_skopeo_copy_case_images() {
    if [ ! -f "${OC_TMP_IMAGE_MAP}" ]; then
        echo "[ERROR] No image mapping found"
        exit 11
    fi

    # replace the original registry with the specified source registry
    if [  ! -z "${SOURCE_REGISTRY}" ]; then
        cat ${OC_TMP_IMAGE_MAP} | sed -e "s/[^\/]*/${SOURCE_REGISTRY}/" 1<> "${OC_TMP_IMAGE_MAP}"
    fi
    # change delimiter from '= to space and add transport
    cat ${OC_TMP_IMAGE_MAP} | sed -e "s/=/ docker:\/\//" 1<> "${OC_TMP_IMAGE_MAP}"

    echo "[INFO] Start mirroring CASE images ..."

    while read in; do
        oc_cmd="skopeo copy --all --authfile ${AUTH_JSON} --dest-tls-verify=false --src-tls-verify=false docker://${in}" ;
        echo "${oc_cmd}"
        eval ${oc_cmd}

        if [[ "$?" -ne 0 ]]; then
            # On error we need to clean up our mirrored csv file
            cleanup_mirrored_csv_files_from_current_run

            exit 11
        fi
    done < ${OC_TMP_IMAGE_MAP}
}

#
# Validates that the OLM catalog image tag must be in the following formats:
# vX.Y[.Z]-YYYYMMDD.HHmmss[-HEXCOMMIT][-OS.ARCH[.VAR]]]
# [v]X.Y[.Z]
# YYYY-MM-DD-HHmmss[-HEXCOMMIT]
#
is_valid_olm_catalog_tag() {
    local tag=$1

    if [[ ${tag} =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?-[0-9]{8}\.[0-9]{6}(-[A-Fa-f0-9]{9})?-(linux|windows)\.(amd64|arm32|arm64|i386|mips64le|ppc64le|s390x|windows-amd64)(.v[5-8])?$ ]]; then
        # OFFICIAL tag with os-arch formats:
        # v4.5.1-20200902.220310-CE62727AE-linux.arm64.v8 or v4.5-20200902.220310-CE62727AE-linux.arm64.v8
        # v4.5.1-20200902.220310-CE62727AE-linux.amd64 or v4.5-20200902.220310-CE62727AE-linux.amd64
        # v4.5.1-20200902.220310-linux.arm64.v8 or v4.5-20200902.220310-linux.arm64.v8
        # v4.5.1-20200902.220310-linux.amd64 or v4.5-20200902.220310-linux.amd64
        echo "true"
    elif [[ ${tag} =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?-[0-9]{8}\.[0-9]{6}(-[A-Fa-f0-9]{9})?$ ]]; then
        # OFFICIAL tag without os-arch formats:
        # v4.5.1-20200902.220310-CE62727AE or v4.5-20200902.220310-CE62727AE
        # v4.5.1-20200902.220310 or v4.5-20200902.220310
        echo "true"
    elif [[ ${tag} =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
        # SEMVER tag with exact match formats: 2.0 or 2.0.1
        echo "true"
    elif [[ ${tag} =~ ^[0-9]+(\.[0-9]+){1,2}-[A-Za-z0-9] ]]; then
        # SEMVER tag with leading match formats: 2.0-beta or 2.1.0-linux.amd64
        echo "true"
    elif [[ ${tag} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}(-[A-Fa-f0-9]{9})?$ ]]; then
        # TIMESTAMP tag with exact match formats: 2020-06-25-052612-e9a7f609f or 2020-06-25-052612
        echo "true"
    elif [[ ${tag} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}(-[A-Fa-f0-9]{9})?-[A-Za-z] ]]; then
        # TIMESTAMP tag with leading match formats: 2020-06-25-052612-e9a7f609f-beta or 2020-06-25-052612-linux.amd64
        echo "true"
    elif [[ ${tag} =~ ^v?[0-9]+$ ]]; then
        # INTEGER tag with exact match formats: v1 or 1
        echo "true"
    elif [[ ${tag} =~ ^v?[0-9]+-[A-Za-z] ]]; then
        # INTEGER tag with leading match formats: v1-beta or 1-linux.amd64
        echo "true"
    else
        # no match
        echo "false"
    fi
}

#
# Returns the significant portion of a supported tag
# 
get_tag_significance() {
    local tag=$1
    local significance=

    if [[ ${tag} =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?-[0-9]{8}\.[0-9]{6}$ || ${tag} =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?-[0-9]{8}\.[0-9]{6}- ]]; then
        # OFFICIAL tag with significant portion: v4.5.1-20200902
        significance=$(echo "${tag}" | sed -e 's|^\(v[0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?-[0-9]\{8\}\).*|\1|')
    elif [[ ${tag} =~ ^[0-9]+(\.[0-9]+){1,2}$ || ${tag} =~ ^[0-9]+(\.[0-9]+){1,2}-[A-Za-z] ]]; then
        # SEMVER tag significant portion: 1.2.3
        significance=$(echo "${tag}" | sed -e 's|^\([0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?\)-.*|\1|')
    elif [[ ${tag} =~ ^[0-9]+(\.[0-9]+){1,2}-[0-9]{4}-[0-9]{2}-[0-9]{2}- ]]; then
        # SEMVER tag with timestamp significant portion: 1.2.3-2020-06-25
        significance=$(echo "${tag}" | sed -e 's|^\([0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?-[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)-.*|\1|')
    elif [[ ${tag} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ || ${tag} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}$ || ${tag} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}-[A-Za-z0-9] ]]; then
        # TIMESTAMP tag significant portion: 2020-06-25
        significance=$(echo "${tag}" | sed -e 's|^\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)-.*|\1|')
    elif [[ ${tag} =~ ^v?[0-9]+$ || ${tag} =~ ^v?[0-9]+-[A-Za-z] ]]; then
        # INTEGER tag significant portion: v1 or 1
        significance=$(echo "${tag}" | sed -e 's|^\(v\?[0-9]\+\)-.*|\1|')
    fi

    echo $significance
}

#
# Tags latest OLM catalog images
#
tag_latest_olm_catalog_images() {
    if [[ ! -z "${DRY_RUN}" ]]; then
        # skip for dry-run
        return
    fi

    if [ -f "${OC_TMP_IMAGE_MAP}.CATALOG" ]; then
        catalog_images=$(cat "${OC_TMP_IMAGE_MAP}.CATALOG" | grep "=olm-catalog=")

        REGISTRY_TLS_ENABLED=false
        if [[ ! -z "${catalog_images}" ]] && [[ "${REGISTRY_TLS_ENABLED}" == "true" ]]; then
            extract_ca_cert
        fi

        for catalog_image in ${catalog_images}; do
            image=$(echo "${catalog_image}" | awk -F'=' '{ print $2 }' | rev | sed -e "s|[^:]*:||" | rev)
            tag=$(echo "${catalog_image}" | awk -F'=' '{ print $2 }' | sed -e "s|.*:||")
            sha=$(echo "${catalog_image}" | awk -F'=' '{ print $1 }' | sed -e "s|.*@||")
            arch=$(echo "${catalog_image}" | awk -F'=' '{ print $4 }')
            latest_tag="latest"

            # append arch to latest_tag
            if [[ ! -z "${arch}" ]]; then
                latest_tag="${latest_tag}-${arch}"
            fi

            # only considers tag with supported format
            if [[ "$(is_valid_olm_catalog_tag ${tag})" == "true" ]]; then
                validate_image_mirror_required_tools
                echo "[INFO] Retrieving image tags from ${image}"
                if [[ "${REGISTRY_TLS_ENABLED}" == "true" ]]; then
                    skopeo_cmd="skopeo list-tags --authfile ${AUTH_JSON} --cert-dir ${AUTH_DATA_PATH}/certs docker://${image}"
                else
                    skopeo_cmd="skopeo list-tags --tls-verify=false --authfile ${AUTH_JSON} docker://${image}"
                fi
                echo "[INFO] ${skopeo_cmd}"
                all_tags=$(${skopeo_cmd} | tr -d "\r|\n| " | sed -e 's|.*"Tags":\[||' | sed -e 's|\].*||' | sed -e 's|"||g' | sed -e 's|,|\n|g' | grep -v '^latest' | sort -V)
                printf "[INFO] Available tags:\n${all_tags}\n"

                if [[ ! -z "${all_tags}" ]]; then
                    last_tag=$(printf "${all_tags}" | tail -1)
                    tag_significane=$(get_tag_significance "${tag}")

                    if [[ ${last_tag} =~ ^${tag_significane} ]]; then
                        # tags the current image as latest if the latest tag already exists 
                        # and the current image is the most recent version
                        echo "[INFO] Tagging ${image}:${tag} as ${image}:${latest_tag}"    

                        oc_cmd="oc image mirror -a ${AUTH_JSON} \"${image}@${sha}\" \"${image}:${latest_tag}\" --filter-by-os '.*' --insecure ${DRY_RUN}"
                        echo "${oc_cmd}"
                        eval ${oc_cmd}

                        mirror_exit=$?

                        if [[ "$mirror_exit" -ne 0 ]]; then
                            echo "[INFO] Retrying tagging ${image}:${tag} as ${image}:${latest_tag} using skopeo"
                            skopeo_cmd="skopeo copy --all --authfile ${AUTH_JSON} --dest-tls-verify=false --src-tls-verify=false docker://${image}@${sha} docker://${image}:${latest_tag}" ;
                            echo "${skopeo_cmd}"
                            eval ${skopeo_cmd}
                            if [[ "$?" -ne 0 ]]; then
                                exit 11
                            fi
                        fi
                    else
                        echo "[INFO] Not most recent tag ${tag}, skip tagging as ${latest_tag}"
                    fi
                fi
            fi
        done
    fi
}


#
# Generates image mapping file
#
generate_image_mapping_file() {
    echo "[INFO] Generating image mapping file ${OC_TMP_IMAGE_MAP}"
    mtype=(IMAGE LIST)
    for type in "${mtype[@]}"; do
        if [ -f "${OC_TMP_IMAGE_MAP}.${type}" ]; then
            # sort and remove duplicates
            cat "${OC_TMP_IMAGE_MAP}.${type}" | sed -e "s|=olm-catalog=.*||g" | sort -u >> "${OC_TMP_IMAGE_MAP}"
            cat "${OC_TMP_IMAGE_MAP}.${type}" | grep -E "=olm-catalog=" | sort -u >> "${OC_TMP_IMAGE_MAP}.CATALOG"
        fi
    done
}

#
# Processes single image mapping
#
process_single_image_mapping() {
    image_identifier=$(echo "${IMAGE}" | sed -e "s/[^/]*\///") # removes registry host
    image_identifier=$(update_image_namespace "${image_identifier}") # updates registry host
    echo "${IMAGE}=${TARGET_REGISTRY}/${image_identifier}" > "${OC_TMP_IMAGE_MAP}"
}

#
# Cleanup the mirrored images CSV files from the current run when 
# oc image mirror command fails
#
cleanup_mirrored_csv_files_from_current_run() {
    echo "[INFO] Deleting mirrored image csv files created during this mirror attempt"
    for mirrored_csv in ${MIRRORED_IMAGE_CSV_CONTEXT[@]}; do
        rm -f ${mirrored_csv}
    done
}

#
# Processes a CASE CSV file and output to ${OC_TMP_IMAGE_MAP} file
#
process_case_csv_file() {
    csv_file="${1}"

    # Begin filtering the images based on input groups
    local readonly base_csv="$(basename ${csv_file})"
    OC_TMP_CSV_DIR=$(mktemp -d ${OC_TMP_DIR}/${OC_TMP_PREFIX}_csv_XXXXXXXXX)
    local tmp_csv_file="${OC_TMP_CSV_DIR}/${base_csv}"
    
    echo "[INFO] Copying image CSV file at ${csv_file} to ${tmp_csv_file} temporarily"

    cp "${csv_file}" "${tmp_csv_file}"

    default_tag=$(date "+%Y%m%d%M%S")

    echo "[INFO] Processing image CSV file at ${tmp_csv_file}"
    
    # process FAT and LIST images, and print $registry/$image_name:$digest=$target_registry/$image_name:$tag
    mtype=(IMAGE LIST)
    for type in "${mtype[@]}"; do
        cat "${tmp_csv_file}" | sed -e "s|[\"']||g" | grep ",${type}," \
        | awk -v target_registry=${TARGET_REGISTRY} -v default_tag=${default_tag} \
            -v ns_action=${NAMESPACE_ACTION} -v ns_value=${NAMESPACE_ACTION_VALUE} -F',' \
        '{ printf $1 "/" $2 "@" $4 "=" target_registry "/" } \
        { split($2, paths, "/"); sub(paths[1], "", $2);
          if (ns_action == "replace") { printf ns_value } \
          else if (ns_action == "prefix") { printf ns_value paths[1] } \
          else if (ns_action == "suffix") { printf paths[1] ns_value } \
          else { printf paths[1] } \
          printf $2
        } \
        { printf ":" ($3 == "" ? default_tag ( $6 != "" ? "-" $6 : "") ( $7 != "" ? "-" $7 : "") : $3) \
        } \
        { print ($11 == "olm-catalog" ? ( "=" $11 "=" $7 ) : "") }' \
        >> "${OC_TMP_IMAGE_MAP}.${type}"
    done

    echo "[INFO] Removing temp directory ${OC_TMP_CSV_DIR}"
    rm -rf "${OC_TMP_CSV_DIR}"
}

#
# Process all the CASE images CSV files found in the CASE archive directory
#
process_case_archive_dir() {
    echo "[INFO] Processing list with images: ${CASE_ARCHIVE_DIR}/deployer-filtered-images.csv"
    # Process all existing CSVs
    for csv_file in $(find ${CASE_ARCHIVE_DIR} -name 'deployer-filtered-images.csv'); do
        process_case_csv_file "${csv_file}"
    done
}

#
# Prints usage menu for 'image mirror' action
#
print_image_mirror_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} image mirror [--dry-run|--show-registries]"
    echo "       [--image IMAGE|--csv IMAGE_CSV_FILE|--dir CASE_ARCHIVE_DIR]"
    echo "       [--ns-replace NAMESPACE|--ns-prefix PREFIX|--ns-suffix SUFFIX]"
    echo "       [--from-registry SOURCE_REGISTRY] --to-registry TARGET_REGISTRY"
    echo ""
    echo "Mirror CASE images to an image registry to prepare for Air-Gapped installation"
    echo ""   
    echo "Options:"
    echo "   --image string                 Image to mirror"
    echo "   --csv string                   CASE images CSV file"
    echo "   --dir string                   CASE archive directory that contains the image CSV files"
    echo "   --ns-replace string            Replace the namespace of the mirror image"
    echo "   --ns-prefix string             Append a prefix to the namespace of the mirror image"
    echo "   --ns-suffix string             Append a suffix to the namespace of the mirror image"
    echo "   --auth string                  auth.json file name to use for authentication to the registry"
    echo "   --from-registry string         Mirror the images from a private registry"
    echo "   --to-registry string           Mirror the images to another private registry"
    echo "   --split-size int               Mirror the images in batches with a given split size. Default is 20"
    echo "   --show-registries              Print the registries that would be used"
    echo "   --show-registries-namespaces   Print the registries and namespaces that would be used"
    echo "   --dry-run                      Print the actions that would be taken"   
    echo "   -h, --help                     Print usage information"
    echo ""
    echo "Example 1: Mirror all CASE images to a private registry"
    echo "${script_name} image mirror --dry-run --dir ./offline --to-registry registry1.example.com:5000"
    echo ""
    echo "Example 2: Mirror all CASE images from a private registry to a another private registry"
    echo "${script_name} image mirror --dry-run --dir ./offline --from-registry registry1.example.com:5000 --to-registry registry2.example.com:5000"   
    echo "" 
    exit 1
}

#
# Parses the CLI arguments for 'mirror' action
#
parse_image_arguments() {

    if [[ "$#" == 0 ]]; then
        print_image_mirror_usage
        exit 1
    fi
    
    # process options
    while [ "$1" != "" ]; do
        case "$1" in
        mirror)
            shift
            IMAGE_MIRROR_ACTION_CALLED="true"
            do_image_mirror "$@"
            break
            ;;
        -h | --help)
            print_image_mirror_usage
            exit 1
            ;;
        *)
            print_image_mirror_usage
            exit 1
            ;;
        esac
        shift
    done
}

#
# Parses the CLI arguments for 'mirror' action
#
parse_image_mirror_arguments() {
    if [[ "$#" == 0 ]]; then
        print_image_mirror_usage
        exit 1
    fi

    # process options
    while [ "$1" != "" ]; do
        case "$1" in
        --image)
            shift
            IMAGE="$1"
            ;;
        --csv)
            shift
            IMAGE_CSV_FILE="$1"
            ;;
        --dir)
            shift
            CASE_ARCHIVE_DIR="$1"
            ;;
        --archive)
            shift
            CASE_ARCHIVE="$1"
            ;;
        --ns-replace)
            shift
            NAMESPACE_ACTION="replace"
            NAMESPACE_ACTION_VALUE="$1"
            ;;
        --ns-prefix)
            shift
            NAMESPACE_ACTION="prefix"
            NAMESPACE_ACTION_VALUE="$1"
            ;;
        --ns-suffix)
            shift
            NAMESPACE_ACTION="suffix"
            NAMESPACE_ACTION_VALUE="$1"
            ;;
        --auth)
            shift
            AUTH_JSON="$1"
            ;;            
        --from-registry)
            shift
            SOURCE_REGISTRY="$1"
            ;;
        --to-registry)
            shift
            TARGET_REGISTRY="$1"
            ;;
        --split-size)
            shift
            OC_TMP_IMAGE_MAP_SPLIT_SIZE=$1
            ;;
        --dry-run)
            DRY_RUN="--dry-run"
            ;;
        --log-dir)
            shift
            LOG_DIR="$1"
            ;;
        -h | --help)
            print_image_mirror_usage
            exit 1
            ;;
        *)
            print_image_mirror_usage
            exit 1
            ;;
        esac
        shift
    done
}

#
# Validates the CLI arguments for 'mirror' action
#
validate_image_mirror_arguments() {

    if [ -z "${IMAGE}" ] && [ -z "${IMAGE_CSV_FILE}" ] && [ -z "${CASE_ARCHIVE_DIR}" ]; then
        echo "[ERROR] One of --image or --csv or --case-dir parameter must be specified"
        exit 1
    fi

    if [ ! -z "${IMAGE_CSV_FILE}" ] && [  ! -z "${CASE_ARCHIVE_DIR}" ]; then
        echo "[ERROR] Only --csv or --case-dir parameter should be specified"
        exit 1
    fi

    if [ ! -z "${IMAGE_CSV_FILE}" ] && [ ! -f "${IMAGE_CSV_FILE}" ]; then
        echo "[ERROR] Invalid image CSV file: ${IMAGE_CSV_FILE}"
        exit 1
    fi

    if [ ! -z "${CASE_ARCHIVE_DIR}" ] && [ ! -d "${CASE_ARCHIVE_DIR}" ]; then
        echo "[ERROR] Invalid CASE archive directory: ${CASE_ARCHIVE_DIR}"
        exit 1
    fi

    if [ ! -z "${CASE_ARCHIVE}" ] && [[ ( ${CASE_ARCHIVE} != *.tgz ) ]]; then
        echo "[ERROR] Invalid CASE archive: ${CASE_ARCHIVE}"
        exit 1
    fi

    if [ ! -z "${NAMESPACE_ACTION}" ] && [ -z "${NAMESPACE_ACTION_VALUE}" ]; then
        echo "[ERROR] Missing an argument for namespace ${NAMESPACE_ACTION}"
        exit 1
    fi

    split_size=$(echo "${OC_TMP_IMAGE_MAP_SPLIT_SIZE}" | grep -E "^\-?[0-9]?\.?[0-9]+$")
    if [ -z "${split_size}" ] || [[ ${OC_TMP_IMAGE_MAP_SPLIT_SIZE} -lt 0 ]]; then
        echo "[ERROR] Invalid split size"
        exit 1
    fi
}

#
# Validate required tools for image mirroring
#
validate_image_mirror_required_tools() {
    if [ -f "${OC_TMP_IMAGE_MAP}.CATALOG" ]; then
        catalog_images=$(cat "${OC_TMP_IMAGE_MAP}.CATALOG" | grep "=olm-catalog=")

        if [[ ! -z "${catalog_images}" ]]; then
            # validate required tools - skopeo
            skopeo_command=$(command -v skopeo 2> /dev/null)
            if [ -z "${skopeo_command}" ];
            then
                echo "[ERROR] skopeo not found. For RHEL, use 'sudo yum install skopeo' to install"
                exit 1
            fi
        fi
    fi
}

#
# Updates image namespace
#
update_image_namespace() {
    image="$1"
    if [ ! -z "${NAMESPACE_ACTION_VALUE}" ]; then
        if [ "${NAMESPACE_ACTION}" == "replace" ]; then
            image=$(echo "${image}" | sed -E "s/([^\/]*)\//${NAMESPACE_ACTION_VALUE}\//")
        elif [ "${NAMESPACE_ACTION}" == "prefix" ]; then
            image=$(echo "${image}" | sed -E "s/([^\/]*)\//${NAMESPACE_ACTION_VALUE}\1\//")
        elif [ "${NAMESPACE_ACTION}" == "suffix" ]; then
            image=$(echo "${image}" | sed -E "s/([^\/]*)\//\1${NAMESPACE_ACTION_VALUE}\//")
        fi
    fi
    echo "${image}"
}

# --- Run ---

main $*
