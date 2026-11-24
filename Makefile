.DEFAULT_GOAL := help
FLUTTER ?= $(shell command -v flutter 2>/dev/null || echo $(HOME)/flutter/bin/flutter)
NODE ?= $(or $(shell command -v node 2>/dev/null),$(lastword $(sort $(wildcard $(HOME)/.nvm/versions/node/*/bin/node))))
MERMAID_CHECK ?= $(HOME)/.claude/tools/mermaid-check/check-mermaid.mjs
MERMAID_DOCS = $(shell grep -rl --include='*.md' '```mermaid' docs README.md AGENTS.md CHANGELOG.md 2>/dev/null)

.PHONY: help get analyze ios-ipa android-apk install-ios install-android docs-check

help: ## Liệt kê lệnh
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-16s %s\n", $$1, $$2}'

get: ## flutter pub get
	$(FLUTTER) pub get

analyze: ## flutter analyze
	$(FLUTTER) analyze

ios-ipa: ## Tải .ipa của commit hiện tại từ GitHub Actions về build-ios/ (chờ nếu đang build)
	PLATFORM=ios ./scripts/pull-build.sh

android-apk: ## Tải .apk của commit hiện tại về build-android/
	PLATFORM=android ./scripts/pull-build.sh

install-ios: ## Tải .ipa của commit hiện tại, ký bằng Apple ID và cài lên iPhone cắm USB
	PLATFORM=ios ./scripts/install-build.sh

install-android: ## Tải .apk của commit hiện tại và cài lên máy Android qua adb
	PLATFORM=android ./scripts/install-build.sh

docs-check: ## Kiểm link, khung mục docs/feature, mermaid (bỏ qua mermaid nếu thiếu NODE/MERMAID_CHECK)
	python3 scripts/check-docs.py .
	@if [ -z "$(MERMAID_DOCS)" ]; then echo "Không có block mermaid"; \
	elif [ -n "$(NODE)" ] && [ -f "$(MERMAID_CHECK)" ]; then "$(NODE)" "$(MERMAID_CHECK)" $(MERMAID_DOCS); \
	else echo "CẢNH BÁO: bỏ qua kiểm mermaid (thiếu node hoặc $(MERMAID_CHECK))"; fi
