export PATH := /opt/homebrew/bin:$(PATH)

# --- Docker Compose (macOS / dev) ---
up:
	docker compose up -d --build

down:
	docker compose down

phone1:
	docker exec -it voip-phone1 baresip -f /root/.baresip

phone2:
	docker exec -it voip-phone2 baresip -f /root/.baresip

# --- ContainerLab (Linux) ---
build:
	docker build -t voip-lab/asterisk ./asterisk
	docker build -t voip-lab/client ./client

deploy: build
	clab deploy -t topology.yml

destroy:
	clab destroy -t topology.yml

clab-phone1:
	docker exec -it clab-voip-phone1 baresip -f /root/.baresip

clab-phone2:
	docker exec -it clab-voip-phone2 baresip -f /root/.baresip

.PHONY: up down build deploy destroy phone1 phone2 clab-phone1 clab-phone2
