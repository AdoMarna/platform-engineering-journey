# orders-platform: local shortcuts. Run `make` to list them.
URL  ?= http://localhost:8080
ITEM ?= keyboard
QTY  ?= 1

.DEFAULT_GOAL := help
.PHONY: help up down clean reset ps logs order orders get ready

help: ## List targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-8s %s\n", $$1, $$2}'

up: ## Build and start the stack, wait until healthy
	docker compose up -d --build --wait

down: ## Stop the stack (data kept)
	docker compose down

clean: ## Stop the stack and delete the data
	docker compose down -v

reset: clean ## Empty database, ids back to 1
	docker compose up -d --wait

ps: ## Service status
	docker compose ps

logs: ## Follow logs (S=api to filter one service)
	docker compose logs -f $(S)

order: ## Create an order (ITEM=mouse QTY=2)
	@curl -sf -X POST $(URL)/api/orders -H 'content-type: application/json' \
		-d '{"item":"$(ITEM)","quantity":$(QTY)}' | jq .

orders: ## List the last 50 orders
	@curl -sf $(URL)/api/orders | jq -r '(["ID","ITEM","QTY","STATUS"], (.[] | [.id, .item, .quantity, .status])) | @tsv' | column -t

get: ## Show one order (ID=1)
	@curl -sf $(URL)/api/orders/$(ID) | jq .

ready: ## API readiness (Postgres + Redis)
	@curl -s http://localhost:3000/readyz | jq .
