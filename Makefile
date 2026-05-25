SHELL := /bin/bash

HUGO ?= hugo
HUGO_CONFIG ?= hugo.toml
HUGO_BASEURL ?= https://spr12ian.github.io/
HUGO_DESTINATION ?= public
HUGO_PORT ?= 1313
HUGO_BIND ?= 127.0.0.1
HUGO_FLAGS ?=
UV ?= uv
UV_CACHE_DIR ?= .uv-cache

PYTHON_SOURCES := export_comments.py

.DEFAULT_GOAL := help

.PHONY: \
	all \
	build \
	check \
	clean \
	distclean \
	doctor \
	export-comments \
	format \
	help \
	lint \
	new \
	preview \
	serve \
	test \
	types

all: check ## Run the default verification targets

build: ## Build the production site into public/
	$(HUGO) --gc --minify --config "$(HUGO_CONFIG)" --destination "$(HUGO_DESTINATION)" --baseURL "$(HUGO_BASEURL)" $(HUGO_FLAGS)

serve: ## Run the local Hugo development server
	$(HUGO) server --buildDrafts --buildFuture --disableFastRender --config "$(HUGO_CONFIG)" --bind "$(HUGO_BIND)" --port "$(HUGO_PORT)" $(HUGO_FLAGS)

preview: build ## Serve the built public/ directory locally
	python3 -m http.server "$(HUGO_PORT)" --bind "$(HUGO_BIND)" --directory "$(HUGO_DESTINATION)"

new: ## Create content with: make new CONTENT=blog/my-post.md
	@test -n "$(CONTENT)" || { echo "Set CONTENT, for example: make new CONTENT=blog/my-post.md"; exit 1; }
	$(HUGO) new content "$(CONTENT)"

check: doctor lint types test build ## Run local checks and a production Hugo build

doctor: ## Print Hugo environment details
	$(HUGO) version
	$(HUGO) env

lint: ## Run Ruff checks for Python helper scripts, when uv is available
	@if command -v "$(UV)" >/dev/null && test -f pyproject.toml; then \
		UV_CACHE_DIR="$(UV_CACHE_DIR)" $(UV) run ruff check $(PYTHON_SOURCES); \
	else \
		echo "Skipping Python lint: uv or pyproject.toml not found."; \
	fi

format: ## Format Python helper scripts, when uv is available
	@if command -v "$(UV)" >/dev/null && test -f pyproject.toml; then \
		UV_CACHE_DIR="$(UV_CACHE_DIR)" $(UV) run ruff format $(PYTHON_SOURCES); \
	else \
		echo "Skipping Python format: uv or pyproject.toml not found."; \
	fi

types: ## Run basedpyright for Python helper scripts, when uv is available
	@if command -v "$(UV)" >/dev/null && test -f pyproject.toml; then \
		UV_CACHE_DIR="$(UV_CACHE_DIR)" $(UV) run basedpyright --level error; \
	else \
		echo "Skipping Python types: uv or pyproject.toml not found."; \
	fi

test: ## Run pytest if tests exist
	@if command -v "$(UV)" >/dev/null && test -d tests; then \
		UV_CACHE_DIR="$(UV_CACHE_DIR)" $(UV) run pytest; \
	else \
		echo "Skipping Python tests: uv or tests/ not found."; \
	fi

export-comments: ## Export Google Form comments into Hugo data files
	@if command -v "$(UV)" >/dev/null; then \
		UV_CACHE_DIR="$(UV_CACHE_DIR)" $(UV) run python export_comments.py; \
	else \
		python3 export_comments.py; \
	fi

clean: ## Remove Hugo build output and generated resources
	rm -rf "$(HUGO_DESTINATION)" resources/_gen .hugo_build.lock

distclean: clean ## Remove local caches as well
	rm -rf "$(UV_CACHE_DIR)" .pytest_cache .ruff_cache .mypy_cache .basedpyright .pyright
	find . -type d -name '__pycache__' -prune -exec rm -rf {} +

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'
