ifeq ("$(wildcard $(HOME)/.env)","")
$(warning ⚠️  No ~/.env file found. Environment variables may not be set.)
endif

# ============================
# Configuration
# ============================
SHELL := /bin/bash

GOOGLE_SERVICE_ACCOUNT_KEY ?= service-account.json

UV_RUN := uv run
PYTHON_DIR ?= .
DIRENV_DIR := $(PYTHON_DIR)/.direnv
DIRENV_ALLOW_STAMP := $(DIRENV_DIR)/allow.stamp

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
	direnv-allow \
	freeze \
	download_sheets_to_sqlite \
	format \
	format_check \
	info \
	key_check \
	lint \
	logs \
	run_queries \
	run_with_log \
	setup \
	test \
	test_all \
	test_only \
	types \

# ============================
# Meta targets
# ============================

all: setup test_only ## Set up dependencies and run the default test target

activate: setup ## Show the command for activating the virtual environment
	@echo "Run this to activate the virtual environment:"
	@echo "source .venv/bin/activate"

setup: ## Set up the uv environment
	uv sync
	@echo "✅ Setup complete."

# ============================
# Info + Utility
# ============================

info: ## Print selected environment configuration values
	@echo "OUR_FINANCES_DRIVE_KEY=$(OUR_FINANCES_DRIVE_KEY)"
	@echo "GOOGLE_SERVICE_ACCOUNT_KEY_FILE=$(GOOGLE_SERVICE_ACCOUNT_KEY_FILE)"

clean: logs ## Remove local caches, logs, and the uv environment
	@echo "🧹 Removing virtual environment..."
	@rm -rf .venv
	@echo "🧹 Removing all __pycache__ directories..."
	@find . -type d -name '__pycache__' -exec rm -rf {} +
	@echo "🧹 Removing type checker caches..."
	@rm -rf .mypy_cache .pyright
	@echo "🧹 Removing log files..."
	@find . -type f -name '*.log' -print | tee logs/deleted_logs.txt | xargs -r rm -f
	@echo "✅ Cleaned all caches and virtual environment."

# ============================
# script
# ============================

key_check: check_env setup ## Check Google service account key access
	@$(MAKE) run_with_log ACTION=key_check COMMAND="$(UV_RUN) python -m script.key_check"

analyze_spreadsheet: check_env setup ## Analyze the configured Google spreadsheet
	@$(MAKE) run_with_log ACTION=analyze_spreadsheet COMMAND="$(UV_RUN) python -m script.analyze_spreadsheet"

db: ## Open the configured SQLite database in sqlitebrowser
	@$(MAKE) run_with_log ACTION=db COMMAND="sqlitebrowser $(OUR_FINANCES_SQLITE_DB_NAME) &"
	@echo "sqlitebrowser $(OUR_FINANCES_SQLITE_DB_NAME) should be running in the background"

direnv-allow: $(DIRENV_ALLOW_STAMP) ## Run direnv allow if .envrc changed

$(DIRENV_ALLOW_STAMP): $(PYTHON_DIR)/.envrc
	@command -v direnv >/dev/null || { echo "❌ direnv is not installed."; exit 1; }
	@echo "🔓 Allowing $(PYTHON_DIR)/.envrc..."
	@install -d "$(DIRENV_DIR)"
	@direnv allow "$(PYTHON_DIR)"
	@touch "$@"

download_sheets_to_sqlite: check_env setup ## Download configured Google Sheets data into SQLite
	@$(MAKE) run_with_log ACTION=download_sheets_to_sqlite COMMAND="$(UV_RUN) python -m script.download_sheets_to_sqlite"
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
	$(UV_RUN) ruff check export_comments.py tests | tee -a "$$log_file"


format: logs ## Format Python code with Ruff
	@log_file="logs/format.log"; \
	echo "🎨 Formatting with Ruff..." | tee "$$log_file"; \
	$(UV_RUN) ruff format export_comments.py tests | tee -a "$$log_file"

format_check: logs ## Check Python formatting with Ruff
	@log_file="logs/format_check.log"; \
	echo "🎨 Checking formatting with Ruff (check mode)..." | tee "$$log_file"; \
	$(UV_RUN) ruff format --check --diff export_comments.py tests | tee -a "$$log_file"

test_all: setup ## Run the full pytest suite
	@echo "🧪 Running pytest..."
	@$(UV_RUN) pytest --maxfail=1 --disable-warnings -q

test_only: setup logs ## Run isolated pytest tests from the tests directory
	@log_file="logs/test_only.log"; \
	echo "🧪 Running isolated unit tests..." | tee "$$log_file"; \
	if find tests -type f \( -name 'test_*.py' -o -name '*_test.py' \) | grep -q .; then \
		$(UV_RUN) pytest tests --maxfail=1 --disable-warnings -q | tee -a "$$log_file"; \
	else \
		echo "No test files found; skipping." | tee -a "$$log_file"; \
	fi; \
	echo "✅ Unit tests complete." | tee -a "$$log_file"

types: logs ## Run pyright type checks
	@log_file="logs/types.log"; \
	echo "🔎 Type checking with pyright..." | tee "$$log_file"; \
	$(UV_RUN) pyright export_comments.py tests | tee -a "$$log_file"

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

run_queries: check_env setup ## Execute SQLite queries from FILE
	@$(MAKE) run_with_log ACTION=execute_sqlite_queries COMMAND="$(UV_RUN) python -m script.execute_sqlite_queries $(FILE)"

.PHONY: export_comments
export_comments: ## Export published Google Form comments into Hugo data files
	$(UV_RUN) python export_comments.py
