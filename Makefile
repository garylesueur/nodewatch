SHELL := /bin/zsh
MODULE_CACHE := $(CURDIR)/work/clang-module-cache
PACKAGE_CACHE := $(CURDIR)/work/swiftpm-cache
SWIFT_ENV := CLANG_MODULE_CACHE_PATH="$(MODULE_CACHE)" SWIFTPM_MODULECACHE_OVERRIDE="$(MODULE_CACHE)"
SWIFT_CACHE_FLAGS := --disable-sandbox --cache-path "$(PACKAGE_CACHE)"
SWIFT_COMPILE_FLAGS := $(SWIFT_CACHE_FLAGS) -Xswiftc -disable-sandbox

.PHONY: bootstrap prepare run build app format format-check lint test coverage doctor check ci pin-actions clean

bootstrap:
	brew bundle
	git config core.hooksPath .githooks

prepare:
	mkdir -p "$(MODULE_CACHE)" "$(PACKAGE_CACHE)"

run: prepare
	$(SWIFT_ENV) swift run $(SWIFT_COMPILE_FLAGS) NodeWatch

build: prepare
	$(SWIFT_ENV) swift build $(SWIFT_COMPILE_FLAGS)

app:
	./scripts/build-app.sh

format:
	swiftformat --cache ignore Sources Tests Package.swift

format-check:
	swiftformat --cache ignore Sources Tests Package.swift --lint

lint:
	swiftlint lint --strict

test: prepare
	$(SWIFT_ENV) swift test $(SWIFT_COMPILE_FLAGS)

coverage: prepare
	$(SWIFT_ENV) swift test $(SWIFT_COMPILE_FLAGS) --enable-code-coverage
	@echo "Coverage data: .build/out/Products/Debug/codecov/NodeWatch.json"

doctor: prepare
	$(SWIFT_ENV) swift package $(SWIFT_CACHE_FLAGS) describe --type json > work/package-description.json
	$(SWIFT_ENV) swift build --build-tests $(SWIFT_COMPILE_FLAGS)
	$(SWIFT_ENV) ./scripts/run-periphery.sh

check: format-check lint test doctor

ci: check

pin-actions:
	npx --yes pin-github-action .github/workflows/*.yml

clean:
	swift package clean
