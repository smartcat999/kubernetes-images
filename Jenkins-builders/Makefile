.PHONY: all
all: build-builder-base;$(info $(M)...Begin to test and build all of binary.) @ ## Test and build all of binary.

REPO ?= 2030047311
EDGE_TAG ?= edge

build-builder-base:
	docker buildx build -f ./Dockerfile_builder_base --platform linux/amd64,linux/arm64 --push -t ${REPO}/builder-base:${EDGE_TAG} .
