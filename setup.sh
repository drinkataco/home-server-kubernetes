#!/usr/bin/env bash
BASE_DIR=$(cd -- "$(dirname -- "$(readlink "$0" || echo "$0")")" && pwd) # get root directory

declare -r BASE_DIR
declare -r ASSETS_DIR="${BASE_DIR}/assets"
declare -r RED="\033[0;31m" # ansi colour code sequence for green text
declare -r GREEN="\033[0;32m" # ansi colour code sequence for green text
declare -r BLUE="\033[0;34m" # ansi colour code sequence for blue text
declare -r NC="\033[0m" # ansi colour code sequence for no colour text

declare K8S_NAMESPACE

#########################################
# Help/Usage information
#########################################
function usage() {
  echo "USAGE: TODO"
}

#########################################
# copy files from containers data directory to the container.
# this is performed recursively as to simulate merging of directories and subdirectories if needed
# arguments:
#   1 - id of container to copy to
#   2 - root assets
#   3 - subdirectory of current job
#######################################
function copy_files() {
  local pod=$1
  local assets_path=$2
  local current_dir="${3:-${assets_path}}"

  for path in "${assets_path}"/*; do
    local dest=${path/${current_dir}/}

    # if the path isn't a file, then we need to ensure the directory is empty before we copy it over
    #   otherwise, we'll step into the directory and perform operations there, recursively
    if [[ ! -f "${path}" ]]; then
      if kubectl exec "${pod}" -n "${K8S_NAMESPACE}" -- ls "${dest}" > /dev/null 2>&1; then
        copy_files "${pod}" "${path}" "${current_dir}"
        return
      fi
    fi

    if [[ $dest != "/*" ]]; then
      echo "...copying ${dest} to ${pod}"
      kubectl cp "${path}" "${pod}:/${dest}" -n "${K8S_NAMESPACE}"
    fi
  done
}

#########################################
# Check that kubernetes namespace exists
# Arguments:
#   1 - namespace to check
# Returns:
#   0 - namespace found
#   1 - namespace not found
#######################################
function check_namespace() {
  local namespace="${1}"
  local output
  output="$(mktemp)"

  if kubectl get namespace "${namespace}" > "${output}" 2>&1; then
    echo -e "${GREEN}Namespace '${namespace}' found${NC}"
    cat "${output}"
    K8S_NAMESPACE="${namespace}"
    return 0
  else
    echo -e "${RED}$(cat "${output}")${NC}\n" >&2
    return 1
  fi
}

#########################################
# Select namespace from available namespaces
#######################################
function select_namespace() {
  local namespaces
  local selection

  # Prompt for namespace to find containers on
  echo -e "${BLUE}Please select your cluster namespace${NC}"
  namespaces=$(kubectl get namespaces --no-headers -o custom-columns=":metadata.name" | grep -v "^kube" | awk 'NR > 1 { printf(", ") } { printf("%s", $0) } END { if (NR > 0) printf("\n") }')
  echo "${namespaces}"
  printf "%s" "> "
  read -r selection
  echo

  if ! check_namespace "${selection}"; then
    select_namespace
  fi
}

#########################################
# Set copy over default configuration for pods defined in /assets
# Arguments
#  * All Script Arguments
# Globals:
#   ASSETS_DIR
#   BLUE
#   K8S_NAMESPACE
#   RED
#   NC
#########################################
function set_defaults() {
  local namespace="${1}"
  local containers_arg="${2}"
  local namespaces
  local containers

  # Locals for k8s
  local service
  local pod

  # Check namespace
  if [[ -z "${namespace}" ]]; then
    select_namespace
  else
    check_namespace "${namespace}"
  fi

  echo

  # Generate containers
  echo -e "${BLUE}Applying default configuration to containers${NC}"

  # Set all containers argument
  if [[ -n "${containers_arg}" ]]; then
    IFS=',' read -r -a containers <<< "$containers_arg"
  fi

  cd "${ASSETS_DIR}"

  for service in *; do
    # If a container parameter passed through, check that this pod is selected
    if [[ -n "$containers_arg" && ! "value ${containers[*]} " =~ " $service " ]]; then
      continue
    fi

    # Check if service exists
    pod=$(kubectl get pods -n "${K8S_NAMESPACE}" -o name \
      --selector app="${service}" \
      --field-selector status.phase==Running \
    )

    if [[ -z "${pod}" ]]; then
      echo -e "${RED}No running pods found for service named '${service}' in namespace ${K8S_NAMESPACE}${NC}"
      continue
    fi

    # TODO If no explicit argument, ask before setting
    if [[ "${containers_args}" != '' ]]; then
      continue
    fi

    # Copy
    echo -e "\n${BLUE}Copying '${service}'${NC}"
    copy_files "${pod:4}" "${ASSETS_DIR}/${service}" "${ASSETS_DIR}/${service}/"
    echo kubectl rollout restart deployment "${service}"
  done

  cd - > /dev/null
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
  local cmd="${1}"; shift

  case "${cmd}" in
    help)
      usage
      ;;
    defaults)
      set_defaults "$@"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
