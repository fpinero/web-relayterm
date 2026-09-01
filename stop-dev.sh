#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${ROOT_DIR}/.tmp/relayterm-dev.pid"

if [[ ! -f "${PID_FILE}" ]]; then
  echo "Relayterm is not running."
  exit 0
fi

read -r SERVER_PID _ <"${PID_FILE}" || true
if [[ ! "${SERVER_PID}" =~ ^[0-9]+$ ]]; then
  echo "Error: invalid PID file at ${PID_FILE}. Remove it manually after inspection."
  exit 1
fi

if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
  rm -f "${PID_FILE}"
  echo "Relayterm was not running. Removed the stale PID file."
  exit 0
fi

PROCESS_COMMAND="$(ps -p "${SERVER_PID}" -o command= 2>/dev/null || true)"
if [[ "${PROCESS_COMMAND}" != *"-m http.server"* ]] \
  || [[ "${PROCESS_COMMAND}" != *"${ROOT_DIR}/public"* ]]; then
  echo "Error: PID ${SERVER_PID} does not belong to this project's development server."
  echo "Refusing to stop: ${PROCESS_COMMAND}"
  exit 1
fi

kill "${SERVER_PID}"
for _ in {1..20}; do
  if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
    rm -f "${PID_FILE}"
    echo "Relayterm development server stopped."
    exit 0
  fi
  sleep 0.25
done

echo "Error: PID ${SERVER_PID} did not stop after SIGTERM."
echo "Inspect the process before forcing termination."
exit 1
