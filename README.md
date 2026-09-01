# Relayterm landing page

This repository contains the provisional public landing page for Relayterm. It is a dependency-free static site served by nginx and packaged for deployment to k3s.

The website is informational only. Relayterm does not depend on this site or any hosted service.

The Relayterm project is open source under the [Apache License 2.0](https://github.com/fpinero/relayterm/blob/main/LICENSE). Its primary source repository is [fpinero/relayterm](https://github.com/fpinero/relayterm); this repository contains only the public website.

## Run locally

Start the dependency-free local server:

```sh
./start-dev.sh
```

Open `http://127.0.0.1:4321/`. Stop it with:

```sh
./stop-dev.sh
```

Set `HOST` or `PORT` to override the defaults. Runtime logs and the PID file stay in the ignored `.tmp/` directory.

## Build the container

```sh
docker build -t relayterm-landing:local .
docker run --rm -p 8080:80 relayterm-landing:local
```

The container exposes HTTP on port 80. TLS terminates outside the pod.

## Deploy to k3s

The production scripts default to the `relayterm` namespace, `fpinero/web-relayterm` image repository, and `linux/arm64` platform. The first deployment should include the infrastructure flag:

```sh
k8s/scripts/release-and-deploy.sh 0.1.0 --with-infra
```

Later releases can omit the tag. The script reads the deployed semantic version and increments its patch component:

```sh
k8s/scripts/release-and-deploy.sh
```

The release flow builds and smoke-tests the container before pushing it, writes the new immutable tag into `k8s/deployment.yaml` before applying it, waits for the rollout, and verifies both public domains. Build and deployment can also run separately:

```sh
k8s/scripts/release-image.sh
k8s/scripts/deploy-k8s.sh 0.1.1
```

Roll back to a specific published image with:

```sh
k8s/scripts/rollback.sh 0.1.0
```

The manifests create a namespace, single-replica Deployment, ClusterIP Service, and Traefik Ingress for `relayterm.com` and `www.relayterm.com`. The Ingress uses Traefik's default certificate behind Cloudflare and does not create a certificate or secret in the cluster.

`IMAGE_REPO`, `PLATFORM`, `NAMESPACE`, and `K8S_DIR` can override the release defaults when needed.

## Verify

```sh
./scripts/check-site.sh
```

The check validates required metadata, links, deployment settings, file size, and the absence of remote runtime assets.
