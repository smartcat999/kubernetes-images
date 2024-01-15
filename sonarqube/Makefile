.PHONY: all

REPO ?= 2030047311

all: build-v8

build-v8:
	VERSION=v8 ./hack/prepare-build.sh
	docker build -f Dockerfile -t ${REPO}/sonarqube:8.9-community \
		--push \
		--build-arg BASE=sonarqube:8.9-community \
		--build-arg PDF_PLUGIN=sonar-pdfreport-plugin-4.0.0.jar .

clean:
	rm -rf ./tmp


