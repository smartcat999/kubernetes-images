.PHONY: all
all: edge;$(info $(M)...Begin to test and build all of binary.) @ ## Test and build all of binary.

REPO ?= 2030047311
EDGE_TAG ?= edge

build-edge:
	docker buildx build -f Dockerfile_edge --platform linux/amd64,linux/arm64 --push -t ${REPO}/alpine:${EDGE_TAG} .