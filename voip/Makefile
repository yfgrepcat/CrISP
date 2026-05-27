build:
	docker build -t voip/asterisk ./asterisk
	docker build -t voip/client ./client

phone-crisp1:
	docker attach --detach-keys="ctrl-c" clab-enterprise-ospf-bgp-phone-crisp1

phone-crisp2:
	docker attach --detach-keys="ctrl-c" clab-enterprise-ospf-bgp-phone-crisp2

.PHONY: build phone-crisp1 phone-crisp2
