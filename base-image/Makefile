.PHONY: all
all: build-alpine-edge build-static-debian11;$(info $(M)...Begin to test and build all of binary.) @ ## Test and build all of binary.

REPO ?= 2030047311
EDGE_TAG ?= edge

build-alpine-edge:
	docker buildx build -f ./alpine/Dockerfile --platform linux/amd64,linux/arm64 --push -t ${REPO}/alpine:${EDGE_TAG} ./alpine/

build-static-debian11:
	docker buildx build -f ./distroless/static-debian12/Dockerfile --platform linux/amd64,linux/arm64 --push -t ${REPO}/static-debian11:${EDGE_TAG} ./distroless/static-debian12/