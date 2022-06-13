#!/bin/bash
BASE_DIR=$(cd -- "$(dirname -- "$(readlink "$0" || echo "$0")")" && pwd) # get root directory

declare -r BASE_DIR
declare -r CERT_MANAGER_VERSION='v1.8.0'
declare -r TRAEFIK_VERSION='v1.7'
declare -r GREEN="\033[0;32m" # ansi colour code sequence for green text
declare -r BLUE="\033[0;34m" # ansi colour code sequence for blue text
declare -r NC="\033[0m" # ansi colour code sequence for no colour text

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
# Install dependencies and start containers
# Arguments
#  * All Script Arguments
# Globals:
#   BASE_DIR
#   GREEN
#   NC
#########################################
function main() {
  install_cert_manager

  # Only install traefik if implicitly implied
  # K3s, for example, automatically ships with traefik so no need to install
  if [[ "$*" == *'--traefik'* ]]; then
    install_traefik
  fi

  apply_k8s
  bash "${BASE_DIR}/scripts/copy_default_data.sh"

  echo -e "${GREEN}Boostrapping completed${NC}"
}

main "$@"
