ifeq ("$(wildcard $(HOME)/.env)","")
$(warning ⚠️  No ~/.env file found. Environment variables may not be set.)
endif

# ============================
# Configuration
# ============================
SHELL := /bin/bash

GOOGLE_SERVICE_ACCOUNT_KEY ?= service-account.json

VENV_DIR := .venv
PYTHON := python3
VPYTHON := $(VENV_DIR)/bin/python
PIP := $(VENV_DIR)/bin/pip
REQUIREMENTS := requirements.txt

TOP_LEVEL_PACKAGES := \
	google-auth \
	gspread \
	pytest \
	beautifulsoup4

REQUIRED_VARS := \
  OUR_FINANCES_DRIVE_KEY \
	GOOGLE_SERVICE_ACCOUNT_KEY_FILE \
	OUR_FINANCES_SQLITE_DB_NAME \
	OUR_FINANCES_SQLITE_ECHO_ENABLED
export $(REQUIRED_VARS)

.DEFAULT_GOAL := all

.PHONY: \
	activate \
	all \
	analyze_spreadsheet \
	batch \
	check_env \
	ci \
	clean \
	db \
	freeze \
	download_sheets_to_sqlite \
	format \
	format_check \
	info \
	install_tools \
	key_check \
	lint \
	logs \
	pipx \
	requirements \
	run_queries \
	run_with_log \
	setup \
	test \
	test_all \
	test_only \
	types \
	venv

# ============================
# Meta targets
# ============================

all: setup test_only ## Set up dependencies and run the default test target

activate: venv ## Show the command for activating the virtual environment
	@echo "Run this to activate the virtual environment:"
	@echo "source $(VENV_DIR)/bin/activate"

setup: requirements install_tools ## Set up the environment and tools
	@echo "✅ Setup complete."

# ============================
# Virtual environment
# ============================

venv: ## Create the Python virtual environment if needed
	@echo "🔧 Creating virtual environment in $(VENV_DIR) if it doesn't exist..."
	@if [ ! -d "$(VENV_DIR)" ]; then \
		$(PYTHON) -m venv $(VENV_DIR); \
		echo "✅ Created virtual environment"; \
	else \
		echo "✅ Virtual environment already exists"; \
	fi

# ============================
# Package installation
# ============================

pipx: venv ## Ensure pipx is installed for Python CLI tools
	@if ! command -v pipx > /dev/null; then \
		echo "📦 Installing pipx..."; \
		$(PYTHON) -m pip install --user pipx; \
		$(PYTHON) -m pipx ensurepath; \
		echo "Please restart your shell or run 'source ~/.profile' to update PATH."; \
		exit 1; \
	else \
		echo "✅ pipx already installed"; \
	fi

install_tools: pipx ## Install formatting, linting, and typing tools
	pipx install --force ruff
	pipx install --force black
	pipx install --force mypy

requirements: venv ## Install Python package requirements and refresh requirements.txt
	@echo "🚀 Upgrading pip, setuptools, and wheel..."
	$(PIP) install --upgrade pip setuptools wheel
	@echo "📦 Installing top-level packages: $(TOP_LEVEL_PACKAGES)"
	$(PIP) install $(TOP_LEVEL_PACKAGES)
	@echo "📝 Writing top-level-only requirements.txt"
	@echo "# Top-level dev dependencies" > $(REQUIREMENTS)
	@for pkg in $(TOP_LEVEL_PACKAGES); do echo $$pkg >> $(REQUIREMENTS); done

freeze: ## Rewrite requirements.txt from TOP_LEVEL_PACKAGES
	@echo "📌 Rewriting $(REQUIREMENTS) with top-level-only packages..."
	@echo "# Top-level dev dependencies" > $(REQUIREMENTS)
	@for pkg in $(TOP_LEVEL_PACKAGES); do echo $$pkg >> $(REQUIREMENTS); done
	@echo "✅ Updated."

# ============================
# Info + Utility
# ============================

info: ## Print selected environment configuration values
	@echo "OUR_FINANCES_DRIVE_KEY=$(OUR_FINANCES_DRIVE_KEY)"
	@echo "GOOGLE_SERVICE_ACCOUNT_KEY_FILE=$(GOOGLE_SERVICE_ACCOUNT_KEY_FILE)"

clean: logs ## Remove local caches, logs, requirements.txt, and the virtual environment
	@echo "🧹 Removing virtual environment..."
	@rm -rf $(VENV_DIR)
	@echo "🧹 Removing all __pycache__ directories..."
	@find . -type d -name '__pycache__' -exec rm -rf {} +
	@echo "🧹 Removing .mypy_cache directory..."
	@rm -rf .mypy_cache
	@echo "🧹 Removing log files..."
	@find . -type f -name '*.log' -print | tee logs/deleted_logs.txt | xargs -r rm -f
	@echo "🧹 Removing requirements.txt ..."
	@rm -rf $(REQUIREMENTS)
	@echo "✅ Cleaned all caches and virtual environment."

# ============================
# script
# ============================

key_check: check_env venv ## Check Google service account key access
	@$(MAKE) run_with_log ACTION=key_check COMMAND="$(VPYTHON) -m script.key_check"

analyze_spreadsheet: check_env venv ## Analyze the configured Google spreadsheet
	@$(MAKE) run_with_log ACTION=analyze_spreadsheet COMMAND="$(VPYTHON) -m script.analyze_spreadsheet"

db: ## Open the configured SQLite database in sqlitebrowser
	@$(MAKE) run_with_log ACTION=db COMMAND="sqlitebrowser $(OUR_FINANCES_SQLITE_DB_NAME) &"
	@echo "sqlitebrowser $(OUR_FINANCES_SQLITE_DB_NAME) should be running in the background"

download_sheets_to_sqlite: check_env venv ## Download configured Google Sheets data into SQLite
	@$(MAKE) run_with_log ACTION=download_sheets_to_sqlite COMMAND="$(VPYTHON) -m script.download_sheets_to_sqlite"
	@echo "sqlitebrowser SQLITE_DATABASE"

# ============================
# Testing & Batching
# ============================

ci: lint format_check types test_only ## Run linting, format checks, type checks, and tests
	@echo "✅ CI checks passed."

test: lint format types test_only ## Run local checks and data workflow tasks
	@echo "Running tests..."
	@$(MAKE) key_check
	@$(MAKE) analyze_spreadsheet
	@$(MAKE) download_sheets_to_sqlite
	@$(MAKE) vacuum_sqlite_database
	@$(MAKE) generate_reports
	@$(MAKE) first_normal_form
	@$(MAKE) execute_sqlite_queries
	@$(MAKE) generate_sqlalchemy_models
	@$(MAKE) execute_sqlalchemy_queries
	@echo "✅ Tests completed."

# ============================
# Linting & Formatting
# ============================

lint: logs ## Run ruff lint checks
	@log_file="logs/lint.log"; \
	echo "🔍 Linting with ruff..." | tee "$$log_file"; \
	ruff check src script tests | tee -a "$$log_file"


format: logs ## Format Python code with black
	@log_file="logs/format.log"; \
	echo "🎨 Formatting with black..." | tee "$$log_file"; \
	black src script tests | tee -a "$$log_file"

format_check: logs ## Check Python formatting with black
	@log_file="logs/format_check.log"; \
	echo "🎨 Checking formatting with black (check mode)..." | tee "$$log_file"; \
	black --check --diff src script tests | tee -a "$$log_file"

test_all: venv ## Run the full pytest suite
	@echo "🧪 Running pytest..."
	@$(VPYTHON) -m pytest --maxfail=1 --disable-warnings -q

test_only: venv logs ## Run isolated pytest tests from the tests directory
	@log_file="logs/test_only.log"; \
	echo "🧪 Running isolated unit tests..." | tee "$$log_file"; \
	if find tests -type f \( -name 'test_*.py' -o -name '*_test.py' \) | grep -q .; then \
		$(VPYTHON) -m pytest tests --maxfail=1 --disable-warnings -q | tee -a "$$log_file"; \
	else \
		echo "No test files found; skipping." | tee -a "$$log_file"; \
	fi; \
	echo "✅ Unit tests complete." | tee -a "$$log_file"

types: logs ## Run mypy type checks
	@log_file="logs/types.log"; \
	echo "🔎 Type checking with mypy..." | tee "$$log_file"; \
	mypy --explicit-package-bases src script tests | tee -a "$$log_file"

check_env: ## Verify required environment variables are set
	@for var in $$REQUIRED_VARS; do \
		if [ -z "$${!var}" ]; then \
			echo "❌ Environment variable $$var is not set."; \
			exit 1; \
		else \
			echo "✅ $$var is set."; \
		fi; \
	done

logs: ## Create the logs directory
	@install -d logs

run_with_log: logs ## Run COMMAND and write output to logs/$(ACTION).log
	@log_file="logs/$(ACTION).log"; \
	echo "🔧 Starting $(ACTION)..." | tee "$$log_file"; \
	eval $(COMMAND) 2>&1 | tee -a "$$log_file"; \
	echo "✅ $(ACTION) finished." | tee -a "$$log_file"

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

run: ## Run an arbitrary COMMAND with ACTION-based logging
	@$(MAKE) run_with_log ACTION=$(ACTION) COMMAND=$(COMMAND)

run_queries: check_env venv ## Execute SQLite queries from FILE
	@$(MAKE) run_with_log ACTION=execute_sqlite_queries COMMAND="$(VPYTHON) -m script.execute_sqlite_queries $(FILE)"

.PHONY: export_comments
export_comments: ## Export published Google Form comments into Hugo data files
	$(VPYTHON) export_comments.py
