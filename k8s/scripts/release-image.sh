#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-relayterm}"
IMAGE_REPO="${IMAGE_REPO:-fpinero/web-relayterm}"
PLATFORM="${PLATFORM:-linux/arm64}"
K8S_DIR="${K8S_DIR:-k8s}"
DEPLOYMENT="relayterm-landing"
CONTAINER="landing"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_version_helpers.sh
source "${SCRIPT_DIR}/_version_helpers.sh"

require_command docker
require_command kubectl

DEPLOYMENT_YAML="${K8S_DIR}/deployment.yaml"
if (($# > 1)); then
  echo "Usage: ${0} [tag]"
  exit 1
fi
TAG="${1:-}"

if [[ -z "${TAG}" ]]; then
  CURRENT_TAG="$(discover_deployment_tag "${DEPLOYMENT}" "${NAMESPACE}" "${CONTAINER}" "${DEPLOYMENT_YAML}" || true)"
  if [[ -z "${CURRENT_TAG}" ]]; then
    echo "Error: could not read the deployed or manifest tag."
    echo "Provide the first tag explicitly: ${0} 0.1.0"
    exit 1
  fi

  TAG="$(bump_patch_tag "${CURRENT_TAG}" || true)"
  if [[ -z "${TAG}" ]]; then
    echo "Error: current tag '${CURRENT_TAG}' is not semantic x.y.z."
    exit 1
  fi
  echo "Detected ${CURRENT_TAG}, building ${TAG}."
fi

validate_tag "${TAG}"
IMAGE="${IMAGE_REPO}:${TAG}"

echo "=== Step 1/4: Build ${IMAGE} for ${PLATFORM} ==="
docker buildx build --platform "${PLATFORM}" -t "${IMAGE}" --load .

echo ""
echo "=== Step 2/4: Smoke test the image ==="
"${SCRIPT_DIR}/../../scripts/smoke-image.sh" "${IMAGE}"

echo ""
echo "=== Step 3/4: Push ${IMAGE} ==="
docker push "${IMAGE}"

echo ""
echo "=== Step 4/4: Synchronize the deployment manifest ==="
sync_tag_in_manifest "${DEPLOYMENT_YAML}" "${IMAGE_REPO}" "${IMAGE}" "${TAG}"
echo "${DEPLOYMENT_YAML} now references ${IMAGE}."
echo "Built and pushed, but not deployed: ${IMAGE}"
