.PTONY: build-container

build-local:
	docker build -f Dockerfile -t 2030047311/yiyaweb:latest .

build-cross-container:
	docker buildx build --platform linux/amd64,linux/arm64 -f Dockerfile -t 2030047311/yiyaweb:latest .