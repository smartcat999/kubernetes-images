.PHONY: all
all: build


build:
	CGO_ENABLED=0  GOOS=linux  GOARCH=amd64  go build -o ./bin/linux/amd64/ main.go
	CGO_ENABLED=0  GOOS=linux  GOARCH=arm64  go build -o ./bin/linux/arm64/ main.go