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
# clab does not build images — run this first, then: clab deploy -t ../topology.clab.yaml
build:
	docker build -t voip-lab/asterisk ./asterisk
	docker build -t voip-lab/client ./client

clab-phone1:
	docker attach --detach-keys="ctrl-c" clab-enterprise-ospf-bgp-phone-site

clab-phone2:
	docker attach --detach-keys="ctrl-c" clab-enterprise-ospf-bgp-phone-nomad

.PHONY: up down phone1 phone2 build clab-phone1 clab-phone2
