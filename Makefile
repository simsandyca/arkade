# Variables
IMAGE_NAME ?= mamebuilder
TAG ?= latest
SHELL := /bin/bash 
DOCKERFILE ?= Dockerfile
GAMES := 1943mii 20pacgal centiped defender dkong gng invaders joust milliped pacman qix
DOCKER := /usr/bin/docker
BUILD := build#
EMU   := emu#
DIRS := $(foreach game,$(GAMES),$(BUILD)/$(game)/)
JSON := $(foreach game,$(GAMES),$(BUILD)/$(game)/$(game).json)
HTML := $(foreach game,$(GAMES),$(BUILD)/$(game)/index.html)
DOCKERFILES := $(foreach game,$(GAMES),Dockerfile.$(game))
REGISTRY := 192.168.1.1:5000
IMAGES := $(GAMES)
CONTAINER := builder
META_FILE := list.xml
EMULARITY := emularity
EMU_URL   := https://github.com/db48x/emularity.git
getgame = $(lastword $(subst /, ,$(dir $*)))
gamejson = $(BUILD)/$(getgame)/$(getgame).json
dock2json = $(BUILD)/$(subst Dockerfile.,,$@)/$(subst Dockerfile.,,$@).json

# Targets
.PHONY: all build help emu $(IMAGES)

all: $(DIRS) $(JSON) emu $(HTML) $(IMAGES)

emu: | $(BUILD)/$(EMU)/ 
	$(DOCKER) run --rm --name $(CONTAINER) -v $(shell pwd)/$(BUILD)/$(EMU):/output \
	$(IMAGE_NAME):$(TAG) \
		make $(foreach json,$(JSON),$(shell cat $(json) | jq -r '"mame\(.sourcestub)"'))

$(BUILD): 
	mkdir -p $@

$(BUILD)/%/: | $(BUILD)
	mkdir -p $@

$(META_FILE): 
	$(DOCKER) run --rm --name $(CONTAINER) $(IMAGE_NAME):$(TAG) mame -listxml $(GAMES) > $(META_FILE)

%.json : $(META_FILE) gamemeta.py 
	./gamemeta.py $(META_FILE) $(notdir $*) > $@

$(EMULARITY): 
	git clone $(EMU_URL) $(EMULARITY)

$(HTML): $(META_FILE) gamehtml.py $(EMULARITY) 

$(DOCKERFILES) : $(JSON) gamedocker.py
	./gamedocker.py $(dock2json) > $@

$(IMAGES): $(DOCKERFILES)
	$(DOCKER) buildx build --platform linux/arm64 -f Dockerfile.$@ -t $@ .
	$(DOCKER) tag $@ $(REGISTRY)/$@
	$(DOCKER) push $(REGISTRY)/$@

%.html: $(JSON) 
	./gamehtml.py  $(gamejson) > $@
	cp $(shell cat $(gamejson) | jq -r '"$(BUILD)/$(EMU)/mame\(.sourcestub).{js,wasm}"') $(dir $*)
	cp -r $(EMULARITY)/*.js $(EMULARITY)/*.js.map $(EMULARITY)/logo $(EMULARITY)/images $(dir $*)
	
## Build the Docker image
docker: Dockerfile Makefile.docker
	$(DOCKER) build -f $(DOCKERFILE) -t $(IMAGE_NAME):$(TAG) .

clean: 
	rm -rf $(BUILD) $(META_FILE) $(EMULARITY) $(DOCKERFILES)
	$(DOCKER) rm -f $(CONTAINER) >/dev/null 2>&1 || true 

## Push the Docker image to a registry
push:
	$(DOCKER) push $(IMAGE_NAME):$(TAG)

## Show help
help:
	@echo "Makefile commands:"
	@echo "  make build         Build the Docker image"
	@echo "  make push          Push the Docker image to the registry"
	@echo "  make help          Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  IMAGE_NAME=<name>     (default: my-image)"
	@echo "  TAG=<tag>             (default: latest)"
	@echo "  DOCKERFILE=<file>     (default: Dockerfile)"

