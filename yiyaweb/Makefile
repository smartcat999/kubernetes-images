.PTONY: all
all: build-local build-cross-image publish-image publish-multi-image

TAG ?= latest

build-local:
	docker build -f Dockerfile -t 2030047311/yiyaweb:${TAG} .
	docker push 2030047311/yiyaweb:${TAG}

build-cross-image:
	docker buildx build --platform linux/amd64,linux/arm64 --push -f Dockerfile -t 2030047311/yiyaweb:${TAG} .

publish-image: build-local;
	scripts/publish.sh 2030047311/yiyaweb:${TAG}

publish-multi-image: build-cross-image;
	scripts/publish.sh 2030047311/yiyaweb:${TAG}

publish-multi-image-local: build-cross-image
	kubectl -n yiyaweb set image deployments.apps yiyaweb-frontend yiyaweb-frontend=2030047311/yiyaweb:${TAG}