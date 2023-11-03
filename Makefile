.PHONY: all

SHELL := /bin/bash
ROOT_DIR := $(PWD)
HELM_DIR := $(ROOT_DIR)/helm
OVERLAY_DIR := $(ROOT_DIR)/overlays

ENV ?= base
OVERLAY := $(OVERLAY_DIR)/$(ENV)

apply:
	@if [ ! -d "$(OVERLAY)" ]; then \
		echo "Overlay named '$(ENV)' doesn't exist"; \
		exit 1; \
	fi

	kubectl kustomize $(OVERLAY) | kubectl apply -f -

dependencies:
	kubectl kustomize --enable-helm $(HELM_DIR) | kubectl apply -f -

delete:
	@if [ ! -d "$(OVERLAY)" ]; then \
		echo "Overlay named '$(ENV)' doesn't exist"; \
		exit 1; \
	fi

	kubectl kustomize $(OVERLAY) | kubectl delete -f -
