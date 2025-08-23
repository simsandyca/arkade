# The Arkade 

This project started out as with me wanting to refresh my DevOps skills. I'd setup a kubernetes cluster using some Raspberry Pi computers and wanted something to deploy. The project builds up javascript/wasm version of the MAME emulator and bundles those into game specific images. There's other targets in the Makefile to deploy and manage the little arcade cluster via a helm chart managed by ArgoCD.

More details on my [Blog](https://blog.hobosuit.com/category/arkade)

## Requirements
To build the emulator images
   - gnu make
   - docker  (the images are arm64 based for my cluster)
   - python

To deploy
   - kubectl (access to a cluster)
   - helm
   - argocd
   - gh

## Instructions

    make mamebuilder
    make

    #To install with helm
    make package install

    #To create projects in argocd (assuming that's aready configured in the cluster)
    make argocd_create argocd_sync
