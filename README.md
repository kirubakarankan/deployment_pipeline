# Zero-downtime deployment strategies on Kubernetes

[![CI](https://github.com/kirubakarankan/deployment_pipeline/actions/workflows/ci.yml/badge.svg)](https://github.com/kirubakarankan/deployment_pipeline/actions/workflows/ci.yml)
[![E2E canary rollback](https://github.com/kirubakarankan/deployment_pipeline/actions/workflows/e2e-canary.yml/badge.svg)](https://github.com/kirubakarankan/deployment_pipeline/actions/workflows/e2e-canary.yml)
[![E2E blue-green rollback](https://github.com/kirubakarankan/deployment_pipeline/actions/workflows/e2e-blue-green.yml/badge.svg)](https://github.com/kirubakarankan/deployment_pipeline/actions/workflows/e2e-blue-green.yml)

Hands-on implementations of the common ways to ship to production without downtime.
Each one runs locally on **kind + Podman**, is tested in **GitHub Actions** on a real
cluster, and shows how a bad release is caught before users notice.

| Strategy | Folder | Tooling | Status |
|---|---|---|---|
| **Canary** with Prometheus-driven automated rollback | [canary/](canary) | Argo Rollouts, Prometheus, Helm | ✅ Done: bad release rolled back in 47s |
| **Rolling update** | `rolling-update/` | Kubernetes Deployment, probes, PDB | 🚧 Planned |
| **Blue-green** with pre/post promotion analysis | [blue-green/](blue-green) | Argo Rollouts, Prometheus, Helm | ✅ Done: bad release blocked before users in 53s, late failure rolled back 76s after the switch |

## Repository layout

```
canary/              Canary strategy: app, Helm chart, kind setup, demo scripts (see its README)
blue-green/          Blue-green strategy: Helm chart, kind setup, demo scripts; reuses the canary app image
infra/terraform/     EKS + VPC on AWS (eu-west-1), shared by all strategies, validated in CI
.github/workflows/   CI for every strategy, plus e2e tests on a kind cluster
```

## Quick start

```bash
brew install podman kind kubectl helm
podman machine init --cpus 4 --memory 6144 && podman machine start
cd canary && make up && make demo
cd ../blue-green && make up && make demo
```

## Stack

Kubernetes (kind / EKS) · Helm · Argo Rollouts · Prometheus · Terraform · GitHub Actions · Podman · Python (FastAPI)
