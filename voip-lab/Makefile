build:
	docker build -t voip-lab/asterisk ./asterisk
	docker build -t voip-lab/client ./client

phone-site:
	docker attach --detach-keys="ctrl-c" clab-enterprise-ospf-bgp-phone-site

phone-nomad:
	docker attach --detach-keys="ctrl-c" clab-enterprise-ospf-bgp-phone-nomad

.PHONY: build phone-site phone-nomad
