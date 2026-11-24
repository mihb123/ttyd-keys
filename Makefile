.DEFAULT_GOAL := help
FLUTTER ?= $(shell command -v flutter 2>/dev/null || echo $(HOME)/flutter/bin/flutter)

.PHONY: help get analyze ios-ipa android-apk

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
