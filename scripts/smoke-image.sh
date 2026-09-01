#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-}"
if [[ -z "${IMAGE}" ]]; then
  echo "Usage: ${0} <image>"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is required."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required."
  exit 1
fi

CONTAINER="relayterm-landing-smoke-$$"

cleanup() {
  docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker run --detach --name "${CONTAINER}" \
  --cap-drop ALL \
  --cap-add CHOWN \
  --cap-add NET_BIND_SERVICE \
  --cap-add SETGID \
  --cap-add SETUID \
  --publish 127.0.0.1::80 \
  "${IMAGE}" >/dev/null

PORT="$(docker port "${CONTAINER}" 80/tcp | sed -E 's/.*:([0-9]+)$/\1/' | head -n 1)"
if [[ ! "${PORT}" =~ ^[0-9]+$ ]]; then
  echo "Error: could not determine the temporary container port."
  exit 1
fi

for _ in {1..30}; do
  if curl --fail --silent "http://127.0.0.1:${PORT}/healthz" | grep -qx 'ok'; then
    break
  fi
  if ! docker inspect "${CONTAINER}" >/dev/null 2>&1; then
    echo "Error: smoke-test container exited before becoming ready."
    exit 1
  fi
  sleep 0.25
done

curl --fail --silent "http://127.0.0.1:${PORT}/healthz" | grep -qx 'ok'
curl --fail --silent "http://127.0.0.1:${PORT}/" \
  | grep -Fq 'The workspace stays.'

echo "Smoke test passed for ${IMAGE}."
