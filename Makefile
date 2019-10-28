
NAME=wall-e
REPO=quay.io/babylonhealth
VERSION=$(shell git describe --abbrev=0 --tags || git rev-parse HEAD)

build:
	docker build --no-cache -t $(REPO)/$(NAME):$(VERSION) .

install: build
	docker push $(REPO)/$(NAME):$(VERSION)
