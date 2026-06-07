# Mempool BIP-110 — StartOS wrapper
#
# Builds TWO packages from one repo:
#   • 0.3.5.1  (Embassy SDK):  manifest.yaml + scripts/embassy.js + start-sdk
#   • 0.4.0    (start-sdk TS):  startos/ + start-cli
# Both produce a single universal .s9pk containing x86_64 + aarch64.
#
# Common targets:
#   make            build the 0.3.x package (mempool-rdts.s9pk) + verify
#   make x86 / arm  build the 0.3.x package for a single arch (faster)
#   make 040        build the 0.4.0 package (mempool-rdts_040.s9pk)
#   make install        install the 0.3.x package (start-cli, 0.3.x server)
#   make install-040    install the 0.4.0 package (start-cli, 0.4.0 server)
#   make release    build BOTH packages into builds/<version>/ + SHA256SUMS
#   make clean      remove all build artifacts

PKG_ID := $(shell yq -r '.id' manifest.yaml)
PKG_VERSION := $(shell yq -r '.version' manifest.yaml)
BUILD_DIR := builds/$(PKG_VERSION)
# 0.3.x service scripts only — exclude the 0.4.0 startos/ sources and deps.
TS_FILES := $(shell find ./ -name \*.ts -not -path './startos/*' -not -path './node_modules/*' -not -path './builds/*')
STARTOS_FILES := $(shell find startos -type f 2>/dev/null)
IMAGE_FILES := Dockerfile docker_entrypoint.sh docker_entrypoint_040.sh assets/utils/* mempool/frontend mempool/backend mempool/rust

.DELETE_ON_ERROR:
.PHONY: all verify install clean x86 arm 040 pack-040 pack-040-x86 pack-040-arm install-040 install-040-x86 install-040-arm release

# ─────────────────────────── 0.3.5.1 (Embassy) ───────────────────────────
all: verify

verify: $(PKG_ID).s9pk
	start-sdk verify s9pk $(PKG_ID).s9pk

install: $(PKG_ID).s9pk
	start-cli package install $(PKG_ID).s9pk

x86:
	@rm -f docker-images/aarch64.tar
	ARCH=x86_64 $(MAKE) $(PKG_ID).s9pk

arm:
	@rm -f docker-images/x86_64.tar
	ARCH=aarch64 $(MAKE) $(PKG_ID).s9pk

scripts/embassy.js: $(TS_FILES)
	deno run --allow-read --allow-write --allow-env --allow-net scripts/bundle.ts

docker-images/x86_64.tar: $(IMAGE_FILES)
ifeq ($(ARCH),aarch64)
else
	mkdir -p docker-images
	docker buildx build --tag start9/$(PKG_ID)/main:$(PKG_VERSION) --platform=linux/amd64 --build-arg PLATFORM=amd64 -o type=docker,dest=docker-images/x86_64.tar .
endif

docker-images/aarch64.tar: $(IMAGE_FILES)
ifeq ($(ARCH),x86_64)
else
	mkdir -p docker-images
	docker buildx build --tag start9/$(PKG_ID)/main:$(PKG_VERSION) --platform=linux/arm64 --build-arg PLATFORM=arm64 -o type=docker,dest=docker-images/aarch64.tar .
endif

$(PKG_ID).s9pk: manifest.yaml instructions.md LICENSE icon.png scripts/embassy.js docker-images/aarch64.tar docker-images/x86_64.tar
	start-sdk pack

# ───────────────────────────── 0.4.0 (start-sdk) ─────────────────────────
# Every 0.4.0 artifact is named with "040" to distinguish it from the 0.3.x
# mempool-rdts.s9pk. Universal builds contain both arches; the *-x86/-arm
# targets build a single arch (much faster for test-server iteration).
040: pack-040

pack-040: $(PKG_ID)_040.s9pk            # universal (x86_64 + aarch64)
pack-040-x86: $(PKG_ID)_040_x86_64.s9pk # single arch
pack-040-arm: $(PKG_ID)_040_aarch64.s9pk

$(PKG_ID)_040.s9pk: javascript/index.js $(STARTOS_FILES) Dockerfile docker_entrypoint_040.sh
	start-cli s9pk pack -o $(PKG_ID)_040.s9pk

$(PKG_ID)_040_x86_64.s9pk: javascript/index.js $(STARTOS_FILES) Dockerfile docker_entrypoint_040.sh
	start-cli s9pk pack --arch=x86_64 -o $(PKG_ID)_040_x86_64.s9pk

$(PKG_ID)_040_aarch64.s9pk: javascript/index.js $(STARTOS_FILES) Dockerfile docker_entrypoint_040.sh
	start-cli s9pk pack --arch=aarch64 -o $(PKG_ID)_040_aarch64.s9pk

javascript/index.js: $(STARTOS_FILES) tsconfig.json node_modules
	npm run build

node_modules: package-lock.json
	npm ci

package-lock.json: package.json
	npm i

install-040: $(PKG_ID)_040.s9pk
	start-cli package install -s $(PKG_ID)_040.s9pk

install-040-x86: $(PKG_ID)_040_x86_64.s9pk
	start-cli package install -s $(PKG_ID)_040_x86_64.s9pk

install-040-arm: $(PKG_ID)_040_aarch64.s9pk
	start-cli package install -s $(PKG_ID)_040_aarch64.s9pk

# ─────────────────────────────── Release (both) ──────────────────────────
# Builds both universal packages into builds/<version>/ with a SHA256SUMS file.
release: $(PKG_ID).s9pk javascript/index.js
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	cp $(PKG_ID).s9pk $(BUILD_DIR)/$(PKG_ID)-0351.s9pk
	start-cli s9pk pack -o $(BUILD_DIR)/$(PKG_ID)-040.s9pk
	cd $(BUILD_DIR) && sha256sum *.s9pk > SHA256SUMS
	@echo ""
	@echo "Release builds in $(BUILD_DIR):"
	@ls -lh $(BUILD_DIR)/
	@echo ""
	@cat $(BUILD_DIR)/SHA256SUMS

clean:
	rm -rf docker-images builds javascript node_modules
	rm -f $(PKG_ID).s9pk $(PKG_ID)_040*.s9pk
	rm -f scripts/*.js
