.PHONY: all
all: build-kube-proxy build-nodejs20;$(info $(M)...Begin to test and build all of binary.) @ ## Test and build all of binary.

REPO ?= 2030047311
EDGE_TAG ?= edge-amd64

build-kube-proxy:
	docker buildx build -f ./kube-proxy/Dockerfile --platform linux/amd64,linux/arm64 --push -t ${REPO}/kube-proxy:v1.21.10-${EDGE_TAG} ./kube-proxy/


build-nodejs20:
	docker buildx build -f ./nodejs20/Dockerfile --platform linux/arm64 --push -t ${REPO}/nodejs20:${EDGE_TAG} ./nodejs20/
