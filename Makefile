# Functions 
define getgame  # extract the game name from a string 
$(strip $(firstword $(foreach game,$(GAMES),$(findstring $(game),$(1)))))
endef

# Variables
CHART_VER := 0.1.6
BUILD_IMAGE ?= mamebuilder
TAG ?= latest
SHELL := /bin/bash 
BUILD_DOCKERFILE ?= Dockerfile
GAMES := 1943mii 20pacgal circus centiped defender dkong gng invaders joust milliped pacman qix robby supertnk topgunnr truxton victory
DOCKER := /usr/bin/docker
HELM   := /usr/local/bin/helm
ARGOCD := /usr/local/bin/argocd
KUBECTL:= /usr/local/bin/kubectl
BUILD := build#
EMU   := emu#
DIRS := $(foreach game,$(GAMES),$(BUILD)/$(game)/)
JSON := $(foreach game,$(GAMES),$(BUILD)/$(game)/$(game).json)
HTML := $(foreach game,$(GAMES),$(BUILD)/$(game)/index.html)
DOCKERFILES := $(foreach game,$(GAMES),$(BUILD)/$(game)/Dockerfile)
REGISTRY ?= docker-registry:5000
IMAGES := $(GAMES)
CONTAINER := builder
META_FILE := list.xml
EMULARITY := emularity
EMU_URL   := https://github.com/db48x/emularity.git
gamejson = $(BUILD)/$(call getgame,$*)/$(call getgame,$*).json
dock2json = $(BUILD)/$(call getgame,$@)/$(call getgame,$@).json

# Targets
.PHONY: all build emu $(IMAGES) games

all: $(DIRS) $(JSON) emu $(HTML) $(IMAGES)

## Build the emulator directory using the mamebuilder image - use sort to uniquify the list
emu: | $(BUILD)/$(EMU)/ 
	$(DOCKER) run --rm --name $(CONTAINER) -v $(shell pwd)/$(BUILD)/$(EMU):/output \
	$(REGISTRY)/$(BUILD_IMAGE):$(TAG) \
		make $(sort $(foreach json,$(JSON),$(shell cat $(json) | jq -r '"mame\(.sourcestub)"')))

## just dump the game list 
games:
	@echo $(GAMES)

$(BUILD): 
	mkdir -p $@

$(BUILD)/%/: | $(BUILD)
	mkdir -p $@

## There's a full build of "recent" mame in the docker container.  mame -listxml will 
## dump the meta data for all games (about 300Mb).  This run is just for the games in 
## our build list.
$(META_FILE): 
	$(DOCKER) run --rm --name $(CONTAINER) $(REGISTRY)/$(BUILD_IMAGE):$(TAG) mame -listxml $(GAMES) > $(META_FILE)

##  parse-up the XML for one game and dump it as json
%.json : $(META_FILE) gamemeta.py 
	./gamemeta.py $(META_FILE) $(call getgame,$*) > $@

$(EMULARITY): 
	git clone $(EMU_URL) $(EMULARITY)

$(HTML): $(META_FILE) gamehtml.py $(EMULARITY) 

$(DOCKERFILES) : $(JSON) gamedocker.py
	./gamedocker.py $(dock2json) > $@

$(IMAGES): $(DOCKERFILES)
	$(DOCKER) buildx build --platform linux/arm64 -t $(REGISTRY)/$@ $(BUILD)/$@
	$(DOCKER) push $(REGISTRY)/$@

## for each index.html file - create that file and copy in everything needed to do the docker build
%.html: $(JSON) 
	./gamehtml.py  $(gamejson) > $@
	cp $(shell cat $(gamejson) | jq -r '"$(BUILD)/$(EMU)/mame\(.sourcestub).{js,wasm}"') $(dir $*)
	cp -r $(EMULARITY)/*.js $(EMULARITY)/*.js.map $(EMULARITY)/logo $(EMULARITY)/images favicon.ico nginx $(dir $*)
	
## Build the Docker image
$(BUILD_IMAGE): Dockerfile Makefile.docker
	$(DOCKER) build -f $(BUILD_DOCKERFILE) -t $@:$(TAG) .
	$(DOCKER) tag $@ $(REGISTRY)/$@
	$(DOCKER) push $(REGISTRY)/$@

## Push the Docker image to a registry
push:
	$(DOCKER) push $(BUILD_IMAGE):$(TAG)

package:
	$(HELM) package --version $(CHART_VER) helm/game 

install:
	@for game in $(GAMES) ; do \
	    $(HELM) install $$game game-$(CHART_VER).tgz \
	        --set image.repository="docker-registry:5000/$$game" \
	        --set image.tag='latest' \
	        --set fullnameOverride="$$game" \
	        --create-namespace \
	        --namespace games ;\
	done
	@$(KUBECTL) apply -f roms-pvc.yaml 

upgrade:
	@for game in $(GAMES) ; do \
	    $(HELM) upgrade $$game game-$(CHART_VER).tgz \
	        --set image.repository="docker-registry:5000/$$game" \
	        --set image.tag='latest' \
	        --set fullnameOverride="$$game" \
	        --namespace games ;\
	done

argocd_create:
	@$(KUBECTL) create ns games || true 
	@$(KUBECTL) apply -f roms-pvc.yaml 
	@for game in $(GAMES) ; do \
	    $(ARGOCD) app create $$game \
	        --repo https://github.com/simsandyca/arkade.git \
	        --path helm/game \
	        --dest-server https://kubernetes.default.svc  \
	        --dest-namespace games \
	        --helm-set image.repository="docker-registry:5000/$$game" \
	        --helm-set image.tag='latest' \
	        --helm-set fullnameOverride="$$game" ;\
	done

argocd_sync:
	@for game in $(GAMES) ; do \
	    $(ARGOCD) app sync $$game ; \
	done

clean: 
	rm -rf $(BUILD) $(META_FILE) $(EMULARITY) game-$(CHART_VER).tgz
	$(DOCKER) rm -f $(CONTAINER) >/dev/null 2>&1 || true 

