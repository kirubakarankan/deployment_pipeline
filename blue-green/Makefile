CLUSTER   ?= blue-green
RELEASE   ?= bluegreen-app
# Podman prefixes local images with localhost/, so use that name everywhere.
IMAGE_REPO ?= localhost/bluegreen-app
IMAGE_TAG  ?= dev
IMAGE      := $(IMAGE_REPO):$(IMAGE_TAG)
CHART     := charts/bluegreen-app
# Same app as the canary demo, no point keeping a second copy of it.
APP_DIR   := ../canary/app
# Argo Rollouts edits the active/preview Service selectors; Helm 4 server-side
# apply would fight it over those fields, so use client-side apply.
HELM_FLAGS := --server-side=false

# Podman by default; `make ENGINE=docker ...` also works.
ENGINE    ?= podman
ifeq ($(ENGINE),podman)
export KIND_EXPERIMENTAL_PROVIDER := podman
endif

ROLLOUTS_CHART_VERSION   := 2.37.7
PROMETHEUS_CHART_VERSION := 25.27.0

.PHONY: help up cluster addons build load deploy release-good release-bad demo status dashboard lint down

help: ## Show targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

up: cluster addons build load deploy ## Create everything from scratch

cluster: ## Create the kind cluster
	kind create cluster --config kind/cluster.yaml --name $(CLUSTER)

addons: ## Install Argo Rollouts and Prometheus
	helm repo add argo https://argoproj.github.io/argo-helm --force-update
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
	helm upgrade --install argo-rollouts argo/argo-rollouts \
		--version $(ROLLOUTS_CHART_VERSION) -n argo-rollouts --create-namespace \
		--set dashboard.enabled=true \
		--set 'dashboard.extraArgs[0]=--namespace=default' --wait
	helm upgrade --install prometheus prometheus-community/prometheus \
		--version $(PROMETHEUS_CHART_VERSION) -n monitoring --create-namespace \
		-f kind/prometheus-values.yaml --wait

build: ## Build the app image
	$(ENGINE) build -f $(APP_DIR)/Containerfile -t $(IMAGE) $(APP_DIR)

load: ## Load the image into kind
	$(ENGINE) save -o /tmp/$(CLUSTER)-image.tar $(IMAGE)
	kind load image-archive /tmp/$(CLUSTER)-image.tar --name $(CLUSTER)
	rm -f /tmp/$(CLUSTER)-image.tar

deploy: ## Deploy v1 (first install goes straight to active)
	helm upgrade --install $(RELEASE) $(CHART) $(HELM_FLAGS) \
		--set image.repository=$(IMAGE_REPO) --set image.tag=$(IMAGE_TAG) \
		--set app.version=v1 --set fault.errorRate=0
	@# helm --wait can't read Rollout status, so wait on its phase directly.
	kubectl wait rollout/$(RELEASE) --for=jsonpath='{.status.phase}'=Healthy --timeout=5m

release-good: ## Ship a healthy v2 - should be promoted
	helm upgrade $(RELEASE) $(CHART) $(HELM_FLAGS) --reuse-values \
		--set app.version=v2 --set fault.errorRate=0 --set fault.latencyMs=0

release-bad: ## Ship a broken v3 (30% errors) - should never go live
	helm upgrade $(RELEASE) $(CHART) $(HELM_FLAGS) --reuse-values \
		--set app.version=v3-bad --set fault.errorRate=0.3

demo: ## Ship a bad release and time how fast it is blocked
	./scripts/demo-rollback.sh $(RELEASE)

status: ## Show rollout status
	kubectl get rollout $(RELEASE) -o wide
	kubectl get analysisrun --sort-by=.metadata.creationTimestamp

dashboard: ## Open the Argo Rollouts dashboard on http://localhost:3100
	kubectl -n argo-rollouts port-forward svc/argo-rollouts-dashboard 3100:3100

lint: ## Lint the chart
	helm lint $(CHART)

down: ## Delete the kind cluster
	kind delete cluster --name $(CLUSTER)
