#!/bin/bash
BASE_DIR=$(cd -- "$(dirname -- "$(readlink "$0" || echo "$0")")" && cd .. && pwd) # get root directory
DATA_DIR="${BASE_DIR}/data"

declare -r BASE_DIR
declare -r DATA_DIR

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

    echo "...copying ${container_path} to ${container_id}"

    # If the path isn't a file, then we need to ensure the directory is empty before we copy it over
    #   otherwise, we'll step into the directory and perform operations there, recursively
    if [[ ! -f "${path}" ]]; then
      if kubectl exec "${container_id}" -- ls "${container_path}" > /dev/null 2>&1; then
        copy_files "${container_id}" "${path}" "${dir}"
        return
      fi
    fi

    echo kubectl cp "${path}" "${container_id}:${container_path}"
  done 
}

#########################################
# Loop through each container subdirectory and copy files onto container
# Globals:
#   DATA_DIR
#########################################
function main() {
  echo -e "\033[0;32mCopying Default Container Config\033[0m"

  for data_path in "${DATA_DIR}"/*; do
    local container_name
    local container_id

    container_name=${data_path##*/}
    container_id=$(get_container "${container_name}")

    if [[ -z "${container_id}" ]]; then
      echo -e "\033[0;31mError searching for ${container_name} pod!\033[0m" >&2
      continue
    fi

    echo -e "\033[0;34mCopying files for container: ${container_name}\033[0m"
    copy_files "${container_id}" "${data_path}" "${DATA_DIR}/${container_name}/" 

    kubectl exec "${container_id}" -- reboot
  done

  echo -e "\033[0;32mCopying Complete\033[0m"
}

main "$@"

