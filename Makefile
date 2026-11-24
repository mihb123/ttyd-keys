.DEFAULT_GOAL := help
FLUTTER ?= $(shell command -v flutter 2>/dev/null || echo $(HOME)/flutter/bin/flutter)
NODE ?= $(or $(shell command -v node 2>/dev/null),$(lastword $(sort $(wildcard $(HOME)/.nvm/versions/node/*/bin/node))))
MERMAID_CHECK ?= $(HOME)/.claude/tools/mermaid-check/check-mermaid.mjs
MERMAID_DOCS = $(shell grep -rl --include='*.md' '```mermaid' docs README.md AGENTS.md CHANGELOG.md 2>/dev/null)

.PHONY: help get analyze ios-ipa android-apk docs-check

help: ## Liệt kê lệnh
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-12s %s\n", $$1, $$2}'

get: ## flutter pub get
	$(FLUTTER) pub get

analyze: ## flutter analyze
	$(FLUTTER) analyze

ios-ipa: ## Tải .ipa iOS mới nhất từ Codemagic về ~/Downloads/ttyd-keys-ios (chờ nếu đang build)
	WORKFLOW=ios-unsigned ./scripts/pull-build.sh

android-apk: ## Tải .apk Android mới nhất từ Codemagic về ~/Downloads/ttyd-keys-android
	WORKFLOW=android-apk ./scripts/pull-build.sh

docs-check: ## Kiểm link, khung mục docs/feature, mermaid (bỏ qua mermaid nếu thiếu NODE/MERMAID_CHECK)
	python3 scripts/check-docs.py .
	@if [ -z "$(MERMAID_DOCS)" ]; then echo "Không có block mermaid"; \
	elif [ -n "$(NODE)" ] && [ -f "$(MERMAID_CHECK)" ]; then "$(NODE)" "$(MERMAID_CHECK)" $(MERMAID_DOCS); \
	else echo "CẢNH BÁO: bỏ qua kiểm mermaid (thiếu node hoặc $(MERMAID_CHECK))"; fi
