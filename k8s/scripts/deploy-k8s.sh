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
require_command curl

if (($# > 2)) || [[ -n "${2:-}" && "${2:-}" != "--with-infra" ]]; then
  echo "Usage: ${0} <tag> [--with-infra]"
  exit 1
fi

TAG="${1:-}"
WITH_INFRA="${SYNC_INFRA:-false}"
if [[ "${2:-}" == "--with-infra" ]]; then
  WITH_INFRA="true"
fi

if [[ -z "${TAG}" ]]; then
  echo "Usage: ${0} <tag> [--with-infra]"
  echo ""
  echo "Currently deployed:"
  kubectl -n "${NAMESPACE}" get deployment "${DEPLOYMENT}" \
    -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image \
    2>/dev/null || echo "  Nothing is deployed. Bootstrap with --with-infra."
  exit 1
fi

validate_tag "${TAG}"
IMAGE="${IMAGE_REPO}:${TAG}"
DEPLOYMENT_YAML="${K8S_DIR}/deployment.yaml"

if [[ "${WITH_INFRA}" == "true" ]]; then
  echo "=== Step 1/4: Apply namespace, Service, and Ingress ==="
  kubectl apply -f "${K8S_DIR}/namespace.yaml"
  kubectl apply -f "${K8S_DIR}/service.yaml"
  kubectl apply -f "${K8S_DIR}/ingress.yaml"
else
  echo "=== Step 1/4: Leave network configuration unchanged ==="
  if ! kubectl -n "${NAMESPACE}" get deployment "${DEPLOYMENT}" >/dev/null 2>&1; then
    echo "Error: deployment '${DEPLOYMENT}' does not exist in namespace '${NAMESPACE}'."
    echo "Bootstrap with: ${0} ${TAG} --with-infra"
    exit 1
  fi
fi

echo ""
echo "=== Step 2/4: Synchronize and apply ${IMAGE} ==="
sync_tag_in_manifest "${DEPLOYMENT_YAML}" "${IMAGE_REPO}" "${IMAGE}" "${TAG}"
kubectl apply -f "${DEPLOYMENT_YAML}"

echo ""
echo "=== Step 3/4: Wait for the rollout ==="
kubectl -n "${NAMESPACE}" rollout status "deployment/${DEPLOYMENT}" --timeout=120s

echo ""
echo "=== Step 4/4: Verify cluster resources and public domains ==="
kubectl -n "${NAMESPACE}" get deployment,service,ingress,pods
for host in "${HOSTS[@]}"; do
  status="$(check_public_url "https://${host}/")"
  echo "https://${host}/ -> ${status}"
  if [[ "${status}" != "200" ]]; then
    echo "Warning: rollout succeeded, but https://${host}/ did not return 200."
  fi
done

echo "Deployed: ${IMAGE}"
echo "Commit ${DEPLOYMENT_YAML}; it records the deployed image tag."
