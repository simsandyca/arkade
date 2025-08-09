# Variables
IMAGE_NAME ?= builder
TAG ?= latest
DOCKERFILE ?= Dockerfile
GAMES := 20pacgal centiped dkong joust pacman qix
DRIVERS := $(addprefix mame,$(filter-out joust,$(GAMES)) williams)
DOCKER := /usr/bin/docker
OUTPUT := output#
JS := $(addsuffix .js,$(addprefix $(OUTPUT)/,$(DRIVERS)))
WASM := $(addsuffix .wasm,$(addprefix $(OUTPUT)/,$(DRIVERS)))
CONTAINER := builder

# Targets
.PHONY: all build help $(GAMES)

all: $(GAMES)

$(GAMES) : $(DRIVERS) 

joust : mamewilliams

$(DRIVERS) : $(JS) $(WASM) 

%.js %.wasm: | $(OUTPUT)
	$(DOCKER) run --rm --name $(CONTAINER) -v $(shell pwd)/output:/output $(IMAGE_NAME):$(TAG) make $(DRIVERS)

$(OUTPUT):
	mkdir -p $(OUTPUT)

## Build the Docker image
docker: Dockerfile Makefile.docker
	$(DOCKER) build -f $(DOCKERFILE) -t $(IMAGE_NAME):$(TAG) .

clean: 
	rm -f $(JS) $(WASM)
	rm -rf $(OUTPUT)
	$(DOCKER) rm -f $(CONTAINER) || true 

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

