.PHONY: all
all: build-alpine-edge build-nodejs20-debian12 build-base-debian12 build-base-nossl-debian12 build-static-debian12;$(info $(M)...Begin to test and build all of binary.) @ ## Test and build all of binary.

REPO ?= 2030047311
EDGE_TAG ?= edge

build-alpine-edge:
	docker buildx build -f ./alpine/Dockerfile --platform linux/amd64,linux/arm64 --push -t ${REPO}/alpine:${EDGE_TAG} ./alpine/

build-nodejs21-alpine:
	docker buildx build -f ./nodejs21/Dockerfile --platform linux/amd64,linux/arm64 --push -t ${REPO}/nodejs21-alpine:${EDGE_TAG} ./nodejs21/

build-nodejs20-debian12:
	docker buildx build -f ./distroless/nodejs20/Dockerfile --platform linux/amd64,linux/arm64 --push -t ${REPO}/nodejs20-debian12:${EDGE_TAG} ./distroless/nodejs20/

build-base-debian12:
	docker buildx build -f ./distroless/base-debian12/Dockerfile --platform linux/amd64,linux/arm64 --push -t ${REPO}/base-debian12:${EDGE_TAG} ./distroless/base-debian12/

build-base-nossl-debian12:
	docker buildx build -f ./distroless/base-nossl-debian12/Dockerfile --platform linux/amd64,linux/arm64 --push -t ${REPO}/base-nossl-debian12:${EDGE_TAG} ./distroless/base-nossl-debian12/

build-static-debian12:
	docker buildx build -f ./distroless/static-debian12/Dockerfile --platform linux/amd64,linux/arm64 --push -t ${REPO}/static-debian12:${EDGE_TAG} ./distroless/static-debian12/

build-static-debian11:
	docker buildx build -f ./distroless/static-debian11/Dockerfile --platform linux/amd64,linux/arm64 --push -t ${REPO}/static-debian11:${EDGE_TAG} ./distroless/static-debian11/

build-base-nossl-debian11:
	docker buildx build -f ./distroless/base-nossl-debian11/Dockerfile --platform linux/amd64,linux/arm64 --push -t ${REPO}/base-nossl-debian11:${EDGE_TAG} ./distroless/base-nossl-debian11/

build-ubi8:
	docker buildx build -f ./ubi/Dockerfile --platform linux/amd64,linux/arm64 --push -t ${REPO}/ubi8:${EDGE_TAG} ./ubi