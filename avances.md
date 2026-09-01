# Project log

## 2026-09-01, provisional landing page and k3s packaging

Implemented a dependency-free, single-page Relayterm landing site with semantic English content, responsive custom CSS, accessible navigation, truthful pre-release messaging, project-specific metadata, favicon, robots and sitemap files, and a generated 1200 by 630 Open Graph image. Added an nginx container with security headers and health checks, k3s Deployment, ClusterIP Service, and Traefik Ingress manifests, plus local build and deployment documentation.

Verified with `./scripts/check-site.sh` (required copy and metadata present, no JavaScript or remote runtime assets, no public em dash, and 23,766 bytes of HTML and CSS), `docker build -t relayterm-landing:test .` (successful image build), a temporary container using the exact dropped and added Linux capabilities from the Deployment followed by HTTP checks (home returned 200 with `text/html; charset=utf-8`, `/healthz` returned `ok`), `kubectl create --dry-run=client --validate=false -f k8s/ -o name` (all three resources parsed), `git diff --check` (clean), and calculated WCAG contrast ratios (16.35:1 main text, 7.80:1 secondary text, and 14.92:1 accent against the page background). Browser-based visual QA remains queued because no supported browser was available in the environment.

## 2026-09-01, local development and semantic release workflow

Added root-level local start and stop scripts with configurable host and port, PID ownership checks, idempotent behavior, and ignored runtime files. Added an image smoke test plus k3s scripts for separate image releases, deployment, combined release and deployment, and explicit rollback. The release flow reads the live Deployment tag with a manifest fallback, increments the semantic patch component, smoke-tests before pushing, synchronizes the immutable tag before applying the manifest, and verifies both `relayterm.com` and `www.relayterm.com`. Added the `relayterm` namespace, an explicit zero-downtime rolling strategy, and the required Traefik ingress class.

Verified every shell script with `bash -n`; tested the version helpers with `1.2.9` producing `1.2.10`; tested manifest synchronization with `2.3.5` updating both the image and change-cause annotation; ran `start-dev.sh` twice on port 4322, confirmed the second start reused the existing process, received HTTP 200, and ran `stop-dev.sh` twice successfully; ran `scripts/smoke-image.sh relayterm-landing:test` successfully; parsed all four Kubernetes resources with `kubectl create --dry-run=client --validate=false -f k8s/ -o name`; reran `scripts/check-site.sh`; and confirmed `git diff --check` passed. No image was pushed and no cluster resources were changed.

## 2026-09-01, open-source identity and project links

Published Relayterm's open-source status and Apache License 2.0 identity in the page description, Open Graph and X metadata, status copy, technical metadata, and footer. Changed the primary `Source` links to the public `fpinero/relayterm` project repository, added direct license links, and retained `fpinero/web-relayterm` only as the explicitly labeled website source. Updated the repository README and automated content checks accordingly.

Verified GitHub reports `fpinero/relayterm` as a public repository on the `main` branch with Apache License 2.0; ran `scripts/check-site.sh` successfully with 24,896 bytes of HTML and CSS; confirmed the old website repository is not labeled as the main `Source`; served the site temporarily on port 4323 and checked the open-source statement and primary repository URL in the HTTP response; stopped the temporary server; and confirmed `git diff --check` passed.

## 2026-09-01, landing image 0.0.1 production deployment

Built the first production image for `linux/arm64`, smoke-tested it locally, published `fpinero/web-relayterm:0.0.1` to Docker Hub, and synchronized the immutable tag in the Deployment manifest. Bootstrapped the `relayterm` namespace in the OCI k3s cluster and created the ClusterIP Service, Traefik Ingress, and single-replica Deployment. The Ingress contains explicit host rules for both `relayterm.com` and `www.relayterm.com` because Cloudflare's CNAME preserves the requested HTTP host.

Verified all five k3s nodes report `arm64` and ready before release; `scripts/smoke-image.sh` passed before the image push; the Deployment rollout completed with one available replica and no pod restarts; Kubernetes reports `fpinero/web-relayterm:0.0.1` as the live image; the Ingress reports both public hosts; both HTTPS URLs returned HTTP 200 through Cloudflare with the expected security headers; the apex response contained the Apache 2.0 open-source statement; and the `www` response contained the Relayterm hero heading.
