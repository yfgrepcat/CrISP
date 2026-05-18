export PATH := /opt/homebrew/bin:$(PATH)

up:
	docker compose up -d --build

down:
	docker compose down

phone1:
	docker exec -it voip-phone1 baresip -f /root/.baresip

phone2:
	docker exec -it voip-phone2 baresip -f /root/.baresip

.PHONY: up down phone1 phone2
