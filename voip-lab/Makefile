export PATH := /opt/homebrew/bin:$(PATH)

# --- Docker Compose ---
up:
	docker compose up -d --build

down:
	docker compose down

phone1:
	docker attach --detach-keys="ctrl-c" voip-phone1

phone2:
	docker attach --detach-keys="ctrl-c" voip-phone2

# --- ContainerLab ---
# Build images first: clab does not build, only pulls/uses existing images.
build:
	docker build -t voip-lab/asterisk ./asterisk
	docker build -t voip-lab/client ./client

# Deploy the clab topology (requires Linux or Lima VM on macOS).
deploy: build
	clab deploy -t topology.clab.yml

# Destroy removes containers AND the virtual network interfaces clab created.
destroy:
	clab destroy -t topology.clab.yml

# Container names are prefixed with clab-<labname>- by ContainerLab.
clab-phone1:
	docker attach --detach-keys="ctrl-c" clab-voip-phone1

clab-phone2:
	docker attach --detach-keys="ctrl-c" clab-voip-phone2

.PHONY: up down phone1 phone2 build deploy destroy clab-phone1 clab-phone2
