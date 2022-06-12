#!/bin/bash
BASE_DIR=$(cd -- "$(dirname -- "$(readlink "$0" || echo "$0")")" && cd .. && pwd) # get root directory
DATA_DIR="${BASE_DIR}/data"

declare -r BASE_DIR
declare -r DATA_DKIR

#########################################
# Get container ID from name
# Arguments:
#   1 - Generic name of container which the ID will be prepended with 
# Returns
#   ID of  container
#######################################
function get_container() {
  local container_name=$1

  kubectl get pods \
    --field-selector=status.phase=Running \
    --no-headers \
    -o custom-columns=':metadata.name' \
    | grep "${container_name}"
}

#########################################
# Copy files from containers data directory to the contaioner.
# This is performed recursively as to simulate merging of directories and subdirectories if needed
# Arguments:
#   1 - ID of container to copy to
#   2 - Path of directory or file to process
#   3 - root directory of container data to copy over
#######################################
function copy_files() {
  local container_id=$1
  local data_path=$2
  local dir=$3

  for path in "${data_path}"/*; do
    local container_path=${path/${dir}//}

    echo "Copying ${container_path} to ${container_id}"

    # If the path isn't a file, then we need to ensure it's empty before we copy it over
    # otherwise, we're going to step into the directory (recursively calling this function)
    if [[ ! -f "${path}" ]]; then
      if kubectl exec "${container_id}" -- ls "${container_path}" > /dev/null 2>&1; then
        copy_files "${container_id}" "${path}" "${dir}"
        return
      fi
    fi

    kubectl cp "${path}" "${container_id}:${container_path}"
  done 
}

#########################################
# Main function
# Globals:
#   DATA_DIR
#########################################
function main() {
  for data_path in "${DATA_DIR}"/*; do
    local container_name
    local container_id

    container_name=${data_path##*/}
    container_id=$(get_container "${container_name}")

    echo -e "\033[0;32mBootstrapping Container: ${container_name}\033[0m"
    copy_files "${container_id}" "${data_path}" "${DATA_DIR}/${container_name}/" 

    kubectl exec "${container_id}" -- reboot

    echo
  done

  echo -e "\033[0;32mBootstrapping Complete!\033[0m"
}

main

