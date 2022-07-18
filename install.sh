#!/bin/bash
BASE_DIR=$(cd -- "$(dirname -- "$(readlink "$0" || echo "$0")")" && pwd) # get root directory

declare -r BASE_DIR
declare -r DATA_DIR="${BASE_DIR}/data"
declare -r CERT_MANAGER_VERSION='v1.8.0'
declare -r TRAEFIK_VERSION='v1.7'
declare -r RED="\033[0;31m" # ansi colour code sequence for green text
declare -r GREEN="\033[0;32m" # ansi colour code sequence for green text
declare -r BLUE="\033[0;34m" # ansi colour code sequence for blue text
declare -r NC="\033[0m" # ansi colour code sequence for no colour text

#########################################
# Usage information
#########################################
function usage() {
  echo " Apply kubernetes config and, if needed, install dependencies and initialise containers with default config
  Arguments:
    --cert-manager - Install cert-manager (https://cert-manager.io/) to manage certificates as resources in kubernetes
    --traefik - Install traefik. Your installation must have traefik for the ingress resources.  Some distributions, such as k3s, ship with traefik by default.
    --initialise - Initialise Containers by copying over default config and then deleting the pod for a correct restart. Without persistent volumes set up this will do nothing.
    --soft-initialise - like initialise, but only attempts to reboot containers so that persistent volumes are not needed. However, some containers (such as flame) cannot be rebooted."
  exit 0
}
#########################################
# Install Cert Manager to manage certificates
# https://cert-manager.io/docs/
# Globals:
#   GREEN
#   NC
#########################################
function install_cert_manager() {
  echo -e "${GREEN}Installing Cert Manager${NC}"
  kubectl apply -f \
    "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
}

#########################################
# Install Cert Manager to manage certificates
# https://cert-manager.io/docs/
# Globals:
#   GREEN
#   NC
#########################################
function install_traefik() {
  echo -e "${GREEN}Installing Traefik${NC}"
  kubectl apply -f \
    "https://raw.githubusercontent.com/traefik/traefik/${TRAEFIK_VERSION}/examples/k8s/traefik-ds.yaml"
}

#########################################
# Apply Kubernetes Config for Home Server
# This function also waits until containers have created before continuing
# Globals:
#   GREEN
#   BLUE
#   NC
#########################################
function apply_k8s() {
  echo -e "${GREEN}Starting Kubernetes Cluster${NC}"
  kubectl apply -k "${BASE_DIR}"

  while true; do
    # Return if all containers created
    if [[ ! "$(kubectl get pods)" =~ 'ContainerCreating' ]]; then
      return
    fi

    echo -e "${BLUE}Waiting for containers to finish creating...${NC}"
    sleep 5 
  done
}

#########################################
# get container id from name
# arguments:
#   1 - generic name of container which the id will be prepended with
# returns
#   id of container
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
# copy files from containers data directory to the contaioner.
# this is performed recursively as to simulate merging of directories and subdirectories if needed
# arguments:
#   1 - id of container to copy to
#   2 - path of directory or file to process
#   3 - root directory of container data to copy over
#######################################
function copy_files() {
  local container_id=$1
  local data_path=$2
  local dir=$3

  for path in "${data_path}"/*; do
    local container_path=${path/${dir}//}

    echo "...copying ${container_path} to ${container_id}"

    # if the path isn't a file, then we need to ensure the directory is empty before we copy it over
    #   otherwise, we'll step into the directory and perform operations there, recursively
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
# Loop through each container subdirectory and copy files onto container
# Globals:
#   DATA_DIR
#   GREEN
#   RED
#   NC
#########################################
function copy_default_data() {
  local soft_init=$1
  echo -e "${GREEN}Copying Default Container Config${NC}"

  for data_path in "${DATA_DIR}"/*; do
    if [[ "$container_name" == 'flame' ]]; then
      echo 'skip flame'
      continue
    fi
    local container_name
    local container_id

    container_name=${data_path##*/}
    container_id=$(get_container "${container_name}")

    if [[ -z "${container_id}" ]]; then
      echo -e "${RED}Error searching for ${container_name} pod!${NC}" >&2
      continue
    fi

    echo -e "\033[0;34mCopying files for container: ${container_name}\033[0m"
    copy_files "${container_id}" "${data_path}" "${DATA_DIR}/${container_name}/" 

    if [[ -n "$soft_init" ]]; then
      kubectl exec "${container_id}" -- reboot
    else
      kubectl delete pod "${container_id}"
    fi
  done

  echo -e "\033[0;32mCopying Complete\033[0m"
}

#########################################
# Install dependencies and start containers
# Arguments
#  * All Script Arguments
# Globals:
#   BASE_DIR
#   GREEN
#   NC
#########################################
function main() {
  if [[ "$1" == 'help' || "$1" == '--help' ]]; then
    usage
  fi

  if [[ "$*" == *'--cert-manager'* ]]; then
    install_cert_manager
  fi

  # Only install traefik if implicitly implied
  # K3s, for example, automatically ships with traefik so no need to install
  if [[ "$*" == *'--traefik'* ]]; then
    install_traefik
  fi

  apply_k8s

  if [[ "$*" == *'--soft-initialise'* ]]; then
    copy_default_data 1
  elif [[ "$*" == *'--initialise'* ]]; then
    copy_default_data
  fi

  echo -e "${GREEN}Boostrapping completed${NC}"
}

main "$@"
