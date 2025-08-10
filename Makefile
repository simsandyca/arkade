# Variables
IMAGE_NAME ?= builder
TAG ?= latest
SHELL := /bin/bash 
DOCKERFILE ?= Dockerfile
GAMES := 1943mii 20pacgal centiped defender dkong gng invaders joust milliped pacman qix
DOCKER := /usr/bin/docker
BUILD := build#
EMU   := emu#
DIRS := $(foreach game,$(GAMES),$(BUILD)/$(game)/)
JSON := $(foreach game,$(GAMES),$(BUILD)/$(game)/$(game).json)
HTML := $(foreach game,$(GAMES),$(BUILD)/$(game)/$(game).html)
CONTAINER := builder
# Built recent MAME and ran mame -listxml |gzip > list.xml.gz 
META_FILE := list.xml.gz

# Targets
.PHONY: all build help emu $(GAMES) 

all: $(GAMES) emu $(HTML)

$(GAMES) : $(DIRS) $(JSON)

emu: | $(BUILD)/$(EMU)/
	$(DOCKER) run --rm --name $(CONTAINER) -v $(shell pwd)/$(BUILD)/$(EMU):/output \
	$(IMAGE_NAME):$(TAG) \
		make $(foreach json,$(JSON),$(shell cat $(json) | jq -r '"mame\(.sourcestub)"'))

$(BUILD): 
	mkdir -p $@

$(BUILD)/%/: | $(BUILD)
	mkdir -p $@

%.json : $(META_FILE) gamemeta.py 
	./gamemeta.py $(META_FILE) $(notdir $*) > $@

%.html: $(META_FILE) gamehtml.py
	./gamehtml.py  $*.json > $@
	cp $(shell cat $*.json | jq -r '"$(BUILD)/$(EMU)/mame\(.sourcestub).{js,wasm}"') $(dir $*)
	
## Build the Docker image
docker: Dockerfile Makefile.docker
	$(DOCKER) build -f $(DOCKERFILE) -t $(IMAGE_NAME):$(TAG) .

clean: 
	rm -rf $(BUILD)
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

