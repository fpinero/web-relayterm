#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
html_file="$root_dir/public/index.html"
css_file="$root_dir/public/styles.css"

require_text() {
  file=$1
  text=$2
  if ! grep -Fq "$text" "$file"; then
    printf 'Missing required text in %s: %s\n' "$file" "$text" >&2
    exit 1
  fi
}

require_text "$html_file" '<html lang="en">'
require_text "$html_file" '<h1 id="hero-title">The workspace stays.'
require_text "$html_file" 'Status: pre-release'
require_text "$html_file" 'There is no download because there is not yet a public release.'
require_text "$html_file" 'https://relayterm.com/og-image.png'
require_text "$html_file" 'Relayterm is open source and licensed under the Apache License 2.0.'
require_text "$html_file" 'https://github.com/fpinero/relayterm'
require_text "$html_file" 'https://github.com/fpinero/relayterm/blob/main/LICENSE'
require_text "$root_dir/k8s/ingress.yaml" 'traefik.ingress.kubernetes.io/router.entrypoints: web,websecure'
require_text "$root_dir/k8s/ingress.yaml" 'traefik.ingress.kubernetes.io/router.tls: "true"'
require_text "$root_dir/k8s/ingress.yaml" 'ingressClassName: traefik'
require_text "$root_dir/k8s/ingress.yaml" 'host: relayterm.com'
require_text "$root_dir/k8s/ingress.yaml" 'host: www.relayterm.com'
require_text "$root_dir/k8s/service.yaml" 'type: ClusterIP'
require_text "$root_dir/k8s/deployment.yaml" 'containerPort: 80'

if grep -Fq ':latest' "$root_dir/k8s/deployment.yaml"; then
  printf 'Deployment image must use an immutable semantic tag.\n' >&2
  exit 1
fi

if [ ! -s "$root_dir/public/og-image.png" ]; then
  printf 'Missing Open Graph image.\n' >&2
  exit 1
fi

if grep -Fq '<script' "$html_file"; then
  printf 'Unexpected JavaScript found in %s\n' "$html_file" >&2
  exit 1
fi

em_dash=$(printf '\342\200\224')
if grep -R -Fq "$em_dash" "$root_dir/public"; then
  printf 'Forbidden em dash found in public content.\n' >&2
  exit 1
fi

if grep -Eiq '(https?:)?//[^" ]+\.(css|js|woff2?)' "$html_file"; then
  printf 'Remote runtime asset found in %s\n' "$html_file" >&2
  exit 1
fi

site_bytes=$(wc -c < "$html_file")
site_bytes=$((site_bytes + $(wc -c < "$css_file")))
if [ "$site_bytes" -ge 81920 ]; then
  printf 'HTML and CSS exceed the 80 KiB budget: %s bytes\n' "$site_bytes" >&2
  exit 1
fi

printf 'Site checks passed (%s bytes of HTML and CSS).\n' "$site_bytes"
