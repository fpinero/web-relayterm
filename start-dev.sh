#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-4321}"
RUNTIME_DIR="${ROOT_DIR}/.tmp"
PID_FILE="${RUNTIME_DIR}/relayterm-dev.pid"
LOG_FILE="${RUNTIME_DIR}/relayterm-dev.log"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required to serve the static site."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required to verify the local server."
  exit 1
fi

if [[ ! "${PORT}" =~ ^[0-9]+$ ]] || ((PORT < 1 || PORT > 65535)); then
  echo "Error: PORT must be an integer between 1 and 65535."
  exit 1
fi

if [[ -f "${PID_FILE}" ]]; then
  read -r EXISTING_PID EXISTING_HOST EXISTING_PORT <"${PID_FILE}" || true
  if [[ "${EXISTING_PID}" =~ ^[0-9]+$ ]] && kill -0 "${EXISTING_PID}" 2>/dev/null; then
    PROCESS_COMMAND="$(ps -p "${EXISTING_PID}" -o command= 2>/dev/null || true)"
    if [[ "${PROCESS_COMMAND}" != *"-m http.server"* ]] \
      || [[ "${PROCESS_COMMAND}" != *"${ROOT_DIR}/public"* ]]; then
      echo "Error: PID ${EXISTING_PID} does not belong to this project's development server."
      echo "Refusing to replace the PID file: ${PROCESS_COMMAND}"
      exit 1
    fi
    echo "Relayterm is already running at http://${EXISTING_HOST:-${HOST}}:${EXISTING_PORT:-${PORT}}/ (PID ${EXISTING_PID})."
    exit 0
  fi
  rm -f "${PID_FILE}"
fi

mkdir -p "${RUNTIME_DIR}"
nohup python3 -m http.server "${PORT}" \
  --bind "${HOST}" \
  --directory "${ROOT_DIR}/public" \
  >"${LOG_FILE}" 2>&1 &
SERVER_PID=$!
printf '%s %s %s\n' "${SERVER_PID}" "${HOST}" "${PORT}" >"${PID_FILE}"

cleanup_failed_start() {
  kill "${SERVER_PID}" 2>/dev/null || true
  rm -f "${PID_FILE}"
}
trap cleanup_failed_start ERR

for _ in {1..20}; do
  if curl --fail --silent --output /dev/null "http://${HOST}:${PORT}/"; then
    trap - ERR
    echo "Relayterm is running at http://${HOST}:${PORT}/"
    echo "Log: ${LOG_FILE}"
    exit 0
  fi
  if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
    break
  fi
  sleep 0.25
done

trap - ERR
cleanup_failed_start
echo "Error: the local server did not start. See ${LOG_FILE}."
exit 1
