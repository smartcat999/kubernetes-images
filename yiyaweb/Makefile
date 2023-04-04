.PTONY: all
all: build-local build-cross-container

build-local:
	docker build -f Dockerfile -t 2030047311/yiyaweb:latest .
	docker push 2030047311/yiyaweb:latest

build-cross-container:
	docker buildx build --platform linux/amd64,linux/arm64 --push -f Dockerfile -t 2030047311/yiyaweb:latest .