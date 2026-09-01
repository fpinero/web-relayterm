#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-relayterm}"
K8S_DIR="${K8S_DIR:-k8s}"
DEPLOYMENT="relayterm-landing"
CONTAINER="landing"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_version_helpers.sh
source "${SCRIPT_DIR}/_version_helpers.sh"

require_command docker
require_command kubectl

TAG=""
INFRA_FLAG=""
for argument in "$@"; do
  case "${argument}" in
    --with-infra)
      INFRA_FLAG="--with-infra"
      ;;
    *)
      if [[ -n "${TAG}" ]]; then
        echo "Usage: ${0} [tag] [--with-infra]"
        exit 1
      fi
      TAG="${argument}"
      ;;
  esac
done

if [[ -z "${TAG}" ]]; then
  CURRENT_TAG="$(discover_deployment_tag "${DEPLOYMENT}" "${NAMESPACE}" "${CONTAINER}" "${K8S_DIR}/deployment.yaml" || true)"
  if [[ -z "${CURRENT_TAG}" ]]; then
    echo "Error: could not read the current tag. Provide one explicitly."
    exit 1
  fi
  TAG="$(bump_patch_tag "${CURRENT_TAG}" || true)"
  if [[ -z "${TAG}" ]]; then
    echo "Error: current tag '${CURRENT_TAG}' is not semantic x.y.z."
    exit 1
  fi
  echo "Detected ${CURRENT_TAG}, releasing ${TAG}."
fi

validate_tag "${TAG}"
"${SCRIPT_DIR}/release-image.sh" "${TAG}"
"${SCRIPT_DIR}/deploy-k8s.sh" "${TAG}" ${INFRA_FLAG:+"${INFRA_FLAG}"}
