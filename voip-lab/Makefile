export PATH := /opt/homebrew/bin:$(PATH)

up:
	docker compose up -d --build

down:
	docker compose down

phone1:
	docker attach --detach-keys="ctrl-c" voip-phone1

phone2:
	docker attach --detach-keys="ctrl-c" voip-phone2

.PHONY: up down phone1 phone2
