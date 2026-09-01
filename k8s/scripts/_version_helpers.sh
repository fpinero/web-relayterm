#!/usr/bin/env bash

require_command() {
  local command_name="$1"
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Error: '${command_name}' is required but not installed."
    exit 1
  fi
}

validate_tag() {
  local tag="$1"
  if [[ ! "${tag}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: tag '${tag}' must use semantic x.y.z format."
    exit 1
  fi
}

extract_tag_from_image() {
  local image="$1"
  if [[ "${image}" == *":"* ]]; then
    printf '%s\n' "${image##*:}"
    return 0
  fi
  return 1
}

bump_patch_tag() {
  local tag="$1"
  if ! printf '%s' "${tag}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    return 1
  fi

  local major minor patch
  major="$(printf '%s' "${tag}" | cut -d. -f1)"
  minor="$(printf '%s' "${tag}" | cut -d. -f2)"
  patch="$(printf '%s' "${tag}" | cut -d. -f3)"
  printf '%s.%s.%s\n' "${major}" "${minor}" "$((patch + 1))"
}

discover_deployment_tag() {
  local deployment="$1"
  local namespace="$2"
  local container="$3"
  local fallback_yaml="${4:-}"
  local cluster_image=""

  cluster_image="$({ kubectl -n "${namespace}" get deployment "${deployment}" \
    -o "jsonpath={.spec.template.spec.containers[?(@.name=='${container}')].image}" \
    2>/dev/null; } || true)"

  if [[ -n "${cluster_image}" ]]; then
    extract_tag_from_image "${cluster_image}" && return 0
  fi

  if [[ -n "${fallback_yaml}" && -f "${fallback_yaml}" ]]; then
    local manifest_image=""
    manifest_image="$({ grep -E '^[[:space:]]*image:' "${fallback_yaml}" \
      | head -n 1 | sed -E 's/^[[:space:]]*image:[[:space:]]*//'; } 2>/dev/null || true)"
    if [[ -n "${manifest_image}" ]]; then
      extract_tag_from_image "${manifest_image}" && return 0
    fi
  fi

  return 1
}

sync_tag_in_manifest() {
  local yaml="$1"
  local repository="$2"
  local image="$3"
  local tag="$4"
  local cause="${5:-release ${tag}}"

  if [[ ! -f "${yaml}" ]]; then
    echo "Error: ${yaml} does not exist." >&2
    return 1
  fi

  sed -E \
    -e "s|^([[:space:]]*image:[[:space:]]*)${repository}:.*|\1${image}|" \
    -e "s|^([[:space:]]*kubernetes\.io/change-cause:[[:space:]]*).*|\1\"${cause}\"|" \
    "${yaml}" >"${yaml}.tmp"
  mv "${yaml}.tmp" "${yaml}"

  if ! grep -q "image: ${image}$" "${yaml}"; then
    echo "Error: could not write '${image}' into ${yaml}." >&2
    echo "Aborting before the manifest can be applied with a stale image." >&2
    return 1
  fi
}

check_public_url() {
  local url="$1"
  local attempts="${2:-6}"
  local status=""

  for _ in $(seq 1 "${attempts}"); do
    status="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "${url}" 2>/dev/null || true)"
    if [[ "${status}" == "200" ]]; then
      break
    fi
    sleep 3
  done

  printf '%s\n' "${status}"
}
