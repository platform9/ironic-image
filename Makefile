.PHONY: help
help:
	@echo "Targets:"
	@echo "  docker -- build the docker image"

IMG_TAG = latest
IMG_REPO = platform9/ironic-image

.PHONY: build push release
build:
	docker build -t $(IMG_REPO):$(IMG_TAG) .

push: build
	docker push $(IMG_REPO):$(IMG_TAG)

release: push
	docker rmi -f `docker images $(IMG_REPO) -q`
