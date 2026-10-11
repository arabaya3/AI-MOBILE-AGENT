# Makefile for TEIA AI Agents

.PHONY: help install setup run test lint format clean docker-build docker-up docker-down

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install dependencies using Poetry
	poetry install

install-dev: ## Install development dependencies
	poetry install --with dev

setup: ## Run initial setup
	bash scripts/setup.sh

shell: ## Activate Poetry shell
	poetry shell

run: ## Run the application
	poetry run uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload

run-prod: ## Run in production mode
	poetry run uvicorn src.main:app --host 0.0.0.0 --port 8000 --workers 4

test: ## Run tests
	poetry run pytest tests/ -v

test-cov: ## Run tests with coverage
	poetry run pytest tests/ -v --cov=src --cov-report=html --cov-report=term

test-unit: ## Run unit tests only
	poetry run pytest tests/unit/ -v

test-integration: ## Run integration tests only
	poetry run pytest tests/integration/ -v

test-e2e: ## Run end-to-end tests only
	poetry run pytest tests/e2e/ -v

lint: ## Run linting checks
	poetry run flake8 src/
	poetry run pylint src/
	poetry run mypy src/

format: ## Format code with black and isort
	poetry run black src/ tests/
	poetry run isort src/ tests/

format-check: ## Check code formatting
	poetry run black --check src/ tests/
	poetry run isort --check-only src/ tests/

security: ## Run security checks
	poetry run bandit -r src/

pre-commit: ## Run pre-commit hooks
	poetry run pre-commit run --all-files

clean: ## Clean up generated files
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} +
	find . -type d -name ".pytest_cache" -exec rm -rf {} +
	find . -type d -name ".mypy_cache" -exec rm -rf {} +
	rm -rf htmlcov/
	rm -rf dist/
	rm -rf build/
	rm -f .coverage

docker-build: ## Build Docker image
	docker build -t teia-ai-agents:latest .

docker-up: ## Start Docker compose services
	docker-compose up -d

docker-down: ## Stop Docker compose services
	docker-compose down

docker-logs: ## View Docker compose logs
	docker-compose logs -f

docker-restart: ## Restart Docker compose services
	docker-compose restart

db-upgrade: ## Run database migrations
	poetry run alembic upgrade head

db-downgrade: ## Rollback database migration
	poetry run alembic downgrade -1

db-revision: ## Create new database migration
	@read -p "Enter migration message: " msg; \
	poetry run alembic revision --autogenerate -m "$$msg"

docs-serve: ## Serve documentation locally
	poetry run mkdocs serve

docs-build: ## Build documentation
	poetry run mkdocs build

update: ## Update dependencies
	poetry update

lock: ## Update lock file
	poetry lock

requirements: ## Export requirements.txt
	poetry export -f requirements.txt --output requirements.txt --without-hashes

version: ## Show current version
	@poetry version

bump-patch: ## Bump patch version
	poetry version patch

bump-minor: ## Bump minor version
	poetry version minor

bump-major: ## Bump major version
	poetry version major
