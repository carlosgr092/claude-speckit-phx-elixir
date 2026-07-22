# claude-speckit-phx-elixir — developer tasks
#
# These targets mirror the GitHub Actions in .github/workflows so you can
# reproduce CI locally before pushing. Optional tools degrade gracefully:
# a missing linter is reported and skipped, never a hard failure — except in
# `make ci`, which is meant to be strict.

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# Files, discovered via git so ignored dirs (.sources, docs/build, ...) never leak in.
SH_FILES   := $(shell git ls-files -- '*.sh')
JSON_FILES := $(shell git ls-files -- '*.json')
YAML_FILES := $(shell git ls-files -- '*.yml' '*.yaml')
HOOK_TESTS := $(wildcard hooks/tests/*.sh)

YAMLLINT_CONF := {extends: relaxed, rules: {line-length: disable, comments: disable, truthy: disable}}

.PHONY: help lint markdown yaml json shellcheck validate test ci

help: ## Show this help
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

lint: markdown yaml json shellcheck ## Run all linters (markdown, yaml, json, shell)

markdown: ## Lint Markdown with markdownlint-cli2
	@if command -v markdownlint-cli2 >/dev/null 2>&1; then \
	  markdownlint-cli2 --config .markdownlint.json \
	    '**/*.md' '!.sources/**' '!docs/build/**' '!docs/comprension/**' '!node_modules/**'; \
	elif command -v npx >/dev/null 2>&1; then \
	  npx --yes markdownlint-cli2 --config .markdownlint.json \
	    '**/*.md' '!.sources/**' '!docs/build/**' '!docs/comprension/**' '!node_modules/**'; \
	else \
	  echo "SKIP markdown: install markdownlint-cli2 (npm i -g markdownlint-cli2)"; \
	fi

yaml: ## Lint YAML with yamllint
	@if command -v yamllint >/dev/null 2>&1; then \
	  [ -z "$(YAML_FILES)" ] || yamllint -d "$(YAMLLINT_CONF)" $(YAML_FILES); \
	else \
	  echo "SKIP yaml: install yamllint (pipx install yamllint)"; \
	fi

json: ## Validate every JSON file parses (+ hooks.json / plugin.json shape)
	@for f in $(JSON_FILES); do jq empty "$$f" || { echo "Invalid JSON: $$f"; exit 1; }; done
	@jq -e 'has("hooks")' hooks/hooks.json >/dev/null || { echo "hooks.json missing 'hooks'"; exit 1; }
	@for k in name version description; do \
	  jq -e --arg k "$$k" 'has($$k)' .claude-plugin/plugin.json >/dev/null \
	    || { echo "plugin.json missing key: $$k"; exit 1; }; \
	done
	@echo "JSON OK ($(words $(JSON_FILES)) files)"

shellcheck: ## ShellCheck all shell scripts (severity=error)
	@if command -v shellcheck >/dev/null 2>&1; then \
	  [ -z "$(SH_FILES)" ] || shellcheck --severity=error --shell=bash $(SH_FILES); \
	  echo "shellcheck OK"; \
	else \
	  echo "SKIP shellcheck: install shellcheck"; \
	fi

validate: ## Validate plugin structure (claude CLI if present, else structural checks)
	@if command -v claude >/dev/null 2>&1; then \
	  claude plugin validate .; \
	else \
	  echo "claude CLI not found — running structural checks"; \
	  bash .github/scripts/structural-checks.sh; \
	fi

test: ## Run hook regression tests (hooks/tests/*.sh)
	@if [ -z "$(HOOK_TESTS)" ]; then echo "No hook tests found."; exit 0; fi
	@rc=0; for t in $(HOOK_TESTS); do \
	  echo "== $$t =="; bash "$$t" || rc=1; \
	done; exit $$rc

ci: lint validate test ## Everything CI runs, strict
	@echo "CI checks complete."
