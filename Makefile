PKG_ID := $(shell yq -r '.id' manifest.yaml)
PKG_VERSION := $(shell yq -r '.version' manifest.yaml)
TS_FILES := $(shell find ./ -name \*.ts)

# delete the target of a rule if it has changed and its recipe exits with a nonzero exit status
.DELETE_ON_ERROR:

all: verify

verify: builds/$(PKG_ID).s9pk
	start-sdk verify s9pk builds/$(PKG_ID).s9pk

install: builds/$(PKG_ID).s9pk
	start-cli package install builds/$(PKG_ID).s9pk

clean:
	rm -rf docker-images
	rm -rf builds
	rm -f $(PKG_ID).s9pk
	rm -f scripts/*.js

scripts/embassy.js: $(TS_FILES)
	deno run --allow-read --allow-write --allow-env --allow-net scripts/bundle.ts

docker-images/x86_64.tar: Dockerfile docker_entrypoint.sh assets/utils/* mempool/frontend mempool/backend mempool/rust
	mkdir -p docker-images
	docker buildx build --tag start9/$(PKG_ID)/main:$(PKG_VERSION) --platform=linux/amd64 --build-arg PLATFORM=amd64 -o type=docker,dest=docker-images/x86_64.tar .

docker-images/aarch64.tar: Dockerfile docker_entrypoint.sh assets/utils/* mempool/frontend mempool/backend mempool/rust
	mkdir -p docker-images
	docker buildx build --tag start9/$(PKG_ID)/main:$(PKG_VERSION) --platform=linux/arm64 --build-arg PLATFORM=arm64 -o type=docker,dest=docker-images/aarch64.tar .

$(PKG_ID).s9pk: manifest.yaml instructions.md LICENSE icon.png scripts/embassy.js docker-images/aarch64.tar docker-images/x86_64.tar
	start-sdk pack

builds/$(PKG_ID).s9pk: $(PKG_ID).s9pk
	mkdir -p builds
	cp $(PKG_ID).s9pk builds/$(PKG_ID).s9pk
	cd builds && sha256sum $(PKG_ID).s9pk > SHA256SUMS
