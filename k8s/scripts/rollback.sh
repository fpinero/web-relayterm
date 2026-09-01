#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-relayterm}"
IMAGE_REPO="${IMAGE_REPO:-fpinero/web-relayterm}"
K8S_DIR="${K8S_DIR:-k8s}"
DEPLOYMENT="relayterm-landing"
CONTAINER="landing"
HOSTS=("relayterm.com" "www.relayterm.com")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_version_helpers.sh
source "${SCRIPT_DIR}/_version_helpers.sh"

require_command kubectl

if (($# > 1)); then
  echo "Usage: ${0} <tag>"
  exit 1
fi

read_live_image() {
  kubectl -n "${NAMESPACE}" get deployment "${DEPLOYMENT}" \
    -o "jsonpath={.spec.template.spec.containers[?(@.name=='${CONTAINER}')].image}" \
    2>/dev/null || true
}

TAG="${1:-}"
if [[ -z "${TAG}" ]]; then
  echo "Usage: ${0} <tag>"
  echo ""
  echo "Currently deployed:"
  echo "  $(read_live_image)"
  echo ""
  echo "Rollout history:"
  kubectl -n "${NAMESPACE}" rollout history "deployment/${DEPLOYMENT}" 2>/dev/null || true
  exit 1
fi

validate_tag "${TAG}"
IMAGE="${IMAGE_REPO}:${TAG}"
CURRENT="$(read_live_image)"

if [[ -z "${CURRENT}" ]]; then
  echo "Error: could not read deployment '${DEPLOYMENT}' in namespace '${NAMESPACE}'."
  exit 1
fi

echo "Current image: ${CURRENT}"
echo "Target image:  ${IMAGE}"
if [[ "${CURRENT}" == "${IMAGE}" ]]; then
  echo "The requested image is already deployed."
  exit 0
fi

echo ""
echo "=== Step 1/4: Check whether the image is available ==="
if command -v docker >/dev/null 2>&1 && docker manifest inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "Confirmed: ${IMAGE} is available."
else
  echo "Warning: the registry check was inconclusive."
  echo "The existing pod remains available if the target image cannot be pulled."
fi

echo ""
echo "=== Step 2/4: Update only the image and change cause ==="
kubectl -n "${NAMESPACE}" set image "deployment/${DEPLOYMENT}" "${CONTAINER}=${IMAGE}"
kubectl -n "${NAMESPACE}" annotate "deployment/${DEPLOYMENT}" \
  kubernetes.io/change-cause="rollback to ${TAG} from ${CURRENT##*:}" --overwrite >/dev/null

echo ""
echo "=== Step 3/4: Wait for the rollback rollout ==="
if ! kubectl -n "${NAMESPACE}" rollout status "deployment/${DEPLOYMENT}" --timeout=120s; then
  echo "The rollout did not complete. The previous pod remains available because maxUnavailable is 0."
  exit 1
fi

echo ""
echo "=== Step 4/4: Verify and synchronize the manifest ==="
LIVE="$(read_live_image)"
echo "Deployment image: ${LIVE}"
for host in "${HOSTS[@]}"; do
  status="$(check_public_url "https://${host}/")"
  echo "https://${host}/ -> ${status}"
done

DEPLOYMENT_YAML="${K8S_DIR}/deployment.yaml"
sync_tag_in_manifest "${DEPLOYMENT_YAML}" "${IMAGE_REPO}" "${IMAGE}" "${TAG}" \
  "rollback to ${TAG} from ${CURRENT##*:}"
echo "Synchronized ${DEPLOYMENT_YAML} to ${IMAGE}. Commit that manifest change."

if [[ "${LIVE}" != "${IMAGE}" ]]; then
  echo "Error: deployment image is '${LIVE}', expected '${IMAGE}'."
  exit 1
fi

echo "Rollback complete: ${CURRENT##*:} -> ${TAG}"
