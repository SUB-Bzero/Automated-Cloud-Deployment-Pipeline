# Convenience targets for the Automated Cloud Deployment Pipeline project.
# Usage: make <target>

SHELL := /bin/bash
AWS_REGION ?= us-east-1
TF_DIR := terraform/envs/dev
TF_BACKEND_FLAGS ?= -backend-config=backend.hcl

.PHONY: help install lint test run-local down bootstrap init plan apply destroy output

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

install: ## Install npm dependencies
	cd app && npm ci

lint: ## Run ESLint
	cd app && npm run lint

test: ## Run unit tests (requires a local PostgreSQL, or TEST_DATABASE_URL)
	cd app && TEST_DATABASE_URL=$${TEST_DATABASE_URL:-postgres://app:app@localhost:5432/appdb} npm test

run-local: ## Start app + database locally with docker compose
	APP_VERSION=local docker compose up --build --wait

down: ## Stop the local docker compose stack
	docker compose down -v

bootstrap: ## One-time: create the S3 state bucket + DynamoDB lock table
	cd terraform/bootstrap && terraform init && terraform apply

init: ## terraform init for the dev environment (uses backend.hcl)
	cd $(TF_DIR) && terraform init $(TF_BACKEND_FLAGS)

plan: ## terraform plan for the dev environment
	cd $(TF_DIR) && terraform plan

apply: ## terraform apply for the dev environment
	cd $(TF_DIR) && terraform apply

destroy: ## Tear down all environment resources (RDS, EC2, ALB, ...)
	cd $(TF_DIR) && terraform destroy

output: ## Show useful outputs (app URL, EC2 IP, ...)
	cd $(TF_DIR) && terraform output
