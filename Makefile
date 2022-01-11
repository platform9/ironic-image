.PHONY: help
help:
	@echo "Targets:"
	@echo "  docker -- build the docker image"

IMG_TAG ?= v1.1.1
IRONIC_REPO ?= platform9/ironic-image
VBMC_REPO ?= platform9/vbmc

.PHONY: build push release
build:
	docker build -t $(IRONIC_REPO):$(IMG_TAG) .

push: build
	docker push $(IRONIC_REPO):$(IMG_TAG)

vbmc:
	cd resources/vbmc && \
	docker build -t $(VBMC_REPO):$(IMG_TAG) . && \
	docker push $(VBMC_REPO):${IMG_TAG}

release: push vbmc
	docker rmi -f `docker images $(IRONIC_REPO) -q`
	docker rmi -f `docker images $(VBMC_REPO) -q`
