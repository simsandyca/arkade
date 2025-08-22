## Arkade Makefile

## Function Definitions
define getgame  # extract the game name from a string 
$(strip $(firstword $(foreach game,$(GAMES),$(findstring $(game),$(1)))))
endef

## Environment Variables
##  These are stored in github variables in the Games environment
VERSION  ?= 0.0.1
REGISTRY ?= docker-registry:5000

## Github Variables 
GH_REPO := https://github.com/simsandyca/arkade.git
GH_ENV  := Games#

## Tools 
SHELL   := /bin/bash 
DOCKER  := $(shell which docker)
HELM    := $(shell which helm)
ARGOCD  := $(shell which argocd)
KUBECTL := $(shell which kubectl)
GH      := $(shell which gh)

## Version Variables
NEXT_VERSION    = $(shell ./incrementpatch.py $(VERSION))
TAG            := $(VERSION)
CHART_VER      := 0.1.6

## Docker Variables
BUILD_IMAGE      := mamebuilder
BUILD_TAG        := latest
BUILD_DOCKERFILE := Dockerfile

## Make Variables
GAMES         := 1943mii 20pacgal circus centiped defender dkong gng 
GAMES         += invaders joust milliped pacman qix robby supertnk 
GAMES         += topgunnr truxton victory
BUILD         := build#
EMU           := emu#
DIRS          := $(foreach game,$(GAMES),$(BUILD)/$(game)/)
JSON          := $(foreach game,$(GAMES),$(BUILD)/$(game)/$(game).json)
HTML          := $(foreach game,$(GAMES),$(BUILD)/$(game)/index.html)
DOCKERFILES   := $(foreach game,$(GAMES),$(BUILD)/$(game)/Dockerfile)
IMAGES        := $(GAMES)
CONTAINER     := builder
META_FILE     := mame_meta_data.xml
EMULARITY     := emularity
EMU_URL       := https://github.com/db48x/emularity.git
gamejson       = $(BUILD)/$(call getgame,$*)/$(call getgame,$*).json
dock2json      = $(BUILD)/$(call getgame,$@)/$(call getgame,$@).json

## Targets
.PHONY: all build emu $(IMAGES) games update_version get_version

all: $(DIRS) $(JSON) emu $(HTML) $(IMAGES) 

## Build the emulator directory using the mamebuilder image - use sort to uniquify the list
## Some emulators work for multiple games so there's an implied mapping from game 
## name to driver sourcestub - e.g. joust -> williams
emu: | $(BUILD)/$(EMU)/ 
	$(DOCKER) run --rm --name $(CONTAINER) -v $(shell pwd)/$(BUILD)/$(EMU):/output \
	$(REGISTRY)/$(BUILD_IMAGE):$(BUILD_TAG) \
		make $(sort $(foreach json,$(JSON),$(shell cat $(json) | jq -r '"mame\(.sourcestub)"')))

## This target just dumps the game list 
games:
	@echo $(GAMES)

$(BUILD): 
	mkdir -p $@

$(BUILD)/%/: | $(BUILD)
	mkdir -p $@

## There's a full build of "recent" mame in the docker container.  `mame -listxml` will 
## dump the meta data for all games (about 300Mb).  This run is just for the games in 
## our build list.
$(META_FILE): 
	$(DOCKER) run --rm --name $(CONTAINER) $(REGISTRY)/$(BUILD_IMAGE):$(BUILD_TAG) mame -listxml $(GAMES) > $(META_FILE)

##  parse-up the XML for one game and dump it as json
%.json : $(META_FILE) gamemeta.py 
	./gamemeta.py $(META_FILE) $(call getgame,$*) > $@

## clone in the emularity javascript launcher project
$(EMULARITY): 
	git clone $(EMU_URL) $(EMULARITY)

$(HTML): $(META_FILE) gamehtml.py $(EMULARITY) 

$(DOCKERFILES) : $(JSON) gamedocker.py
	./gamedocker.py $(dock2json) > $@

$(IMAGES): TAG = $(NEXT_VERSION)
$(IMAGES): $(DOCKERFILES)
	$(DOCKER) buildx build --platform linux/arm64 -t $(REGISTRY)/$@ $(BUILD)/$@:$(TAG)
	$(DOCKER) push $(REGISTRY)/$@:$(TAG)

## For each "index.html" target build up the "/var/www/html" directory needed to serve the game. 
## this includes index.html file, the emularity launcher js code and assets as well as the 
## game emulator (driver) js and wasm files.
%.html: $(JSON) 
	./gamehtml.py  $(gamejson) > $@
	cp $(shell cat $(gamejson) | jq -r '"$(BUILD)/$(EMU)/mame\(.sourcestub).{js,wasm}"') $(dir $*)
	cp -r $(EMULARITY)/*.js $(EMULARITY)/*.js.map $(EMULARITY)/logo $(EMULARITY)/images favicon.ico nginx $(dir $*)
	
## Build the builder image
$(BUILD_IMAGE): Dockerfile Makefile.docker
	$(DOCKER) build -f $(BUILD_DOCKERFILE) -t $(REGISTRY)/$@:$(BUILD_TAG) .
	$(DOCKER) push $(REGISTRY)/$@:$(BUILD_TAG)

package:
	$(HELM) package --version $(CHART_VER) helm/game 

install: TAG = $(VERSION)
install:
	@for game in $(GAMES) ; do \
	    $(HELM) install $$game game-$(CHART_VER).tgz \
	        --set image.repository="$(REGISTRY)/$$game" \
	        --set image.tag='$(TAG)' \
	        --set fullnameOverride="$$game" \
	        --create-namespace \
	        --namespace games ;\
	done
	@$(KUBECTL) apply -f roms-pvc.yaml 

upgrade: TAG = $(NEXT_VERSION)
upgrade:
	@for game in $(GAMES) ; do \
	    $(HELM) upgrade $$game game-$(CHART_VER).tgz \
	        --set image.repository="$(REGISTRY)/$$game" \
	        --set image.tag='$(TAG)' \
	        --set fullnameOverride="$$game" \
	        --namespace games ;\
	done

argocd_create: TAG = $(VERSION)
argocd_create:
	@$(KUBECTL) create ns games || true 
	@$(KUBECTL) apply -f roms-pvc.yaml 
	@for game in $(GAMES) ; do \
	    $(ARGOCD) app get $$game > /dev/null 2>&1  ; \
	    if [[ $$? != 0 ]] ; then \
	        $(ARGOCD) app create $$game \
	            --repo $(GH_REPO) \
	            --path helm/game \
	            --dest-server https://kubernetes.default.svc  \
	            --dest-namespace games \
	            --helm-set image.repository="$(REGISTRY)/$$game" \
	            --helm-set image.tag='$(TAG)' \
	            --helm-set fullnameOverride="$$game" ;\
	    fi ;\
	done

## The main "Make" workflow in github is going to update_version once the build is 
## successful.  The Argo workflow should run after that - so we want to pull the "existing" 
## (just updated version) for the sync 
argocd_sync: TAG = $(VERSION)
argocd_sync: 
	@for game in $(GAMES) ; do \
	    $(ARGOCD) app set $$game --helm-set image.tag='$(TAG)' ; \
	    $(ARGOCD) app sync $$game ; \
	done

## bump the VERSION variable in github with the new version
update_version:  TAG = $(NEXT_VERSION)
update_version:
	@$(GH) variable set VERSION --env $(GH_ENV) --body "$(TAG)"

get_version: 
	@$(GH) variable list --env $(GH_ENV) --json name,value --jq '.[]|select(.name=="VERSION")|.value'

clean: 
	rm -rf $(BUILD) $(META_FILE) $(EMULARITY) game-$(CHART_VER).tgz
	$(DOCKER) rm -f $(CONTAINER) >/dev/null 2>&1 || true 

