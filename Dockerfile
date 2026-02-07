###############################################################################
# Stage 1: Build the BIP-110 frontend from source
###############################################################################
FROM node:22.14.0-bookworm-slim AS frontend-builder

WORKDIR /build
COPY mempool/frontend/ .
RUN apt-get update && apt-get install -y build-essential rsync && apt-get clean
RUN cp mempool-frontend-config.sample.json mempool-frontend-config.json
ENV SKIP_SYNC=1
ENV CYPRESS_INSTALL_BINARY=0
RUN npm install --omit=dev --omit=optional
RUN npm run build

###############################################################################
# Stage 2: Build the BIP-110 backend from source (includes Rust GBT)
###############################################################################
FROM rust:1.84-bookworm AS backend-builder

WORKDIR /build

# Install Node.js 22
RUN apt-get update && \
  apt-get install -y curl ca-certificates && \
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
  apt-get install -y nodejs=22.14.0-1nodesource1 build-essential python3 pkg-config && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy backend and rust sources
COPY mempool/backend/ .
COPY mempool/rust/ ../rust/

ENV PATH="/usr/local/cargo/bin:$PATH"
ENV FD=/build/rust-gbt
RUN npm install --omit=dev --omit=optional
RUN npm run package

###############################################################################
# Stage 3: Final image — MariaDB + nginx + backend + frontend + Start9 wrapper
###############################################################################
FROM rust:1.84-bookworm

ENV MEMPOOL_CLEAR_PROTECTION_MINUTES="20"
ENV MEMPOOL_INDEXING_BLOCKS_AMOUNT="52560"
ENV MEMPOOL_STDOUT_LOG_MIN_PRIORITY="info"
ENV LIGHTNING_STATS_REFRESH_INTERVAL=3600
ENV LIGHTNING_GRAPH_REFRESH_INTERVAL=3600
ENV MEMPOOL_AUTOMATIC_POOLS_UPDATE=true

USER root
# arm64 or amd64
ARG PLATFORM
# aarch64 or x86_64
ARG ARCH
# Install necessary packages
RUN apt-get update && \
  apt-get install -y --allow-downgrades nginx wait-for-it wget netcat-traditional \
  build-essential python3 pkg-config rsync gettext iproute2 pwgen \
  && wget https://github.com/mikefarah/yq/releases/download/v4.6.3/yq_linux_${PLATFORM}.tar.gz -O - |\
  tar xz && mv yq_linux_${PLATFORM} /usr/bin/yq \
  && apt-get clean

# Install Node.js 22 for backend runtime
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
  apt-get install -y nodejs=22.14.0-1nodesource1 && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Create mysql user and group
RUN groupadd -r mysql && useradd -r -g mysql mysql

# Install required base libraries
RUN apt-get update && \
  apt-get install -y curl gnupg lsb-release ca-certificates libncurses5 libjemalloc2 socat

# Install libssl1.1 from Buster (needed by MariaDB 10.4)
RUN echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list.d/buster.list && \
  echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until && \
  apt-get update && \
  apt-get install -y libssl1.1

# Install MariaDB 10.4 via .deb packages
RUN set -eux; \
  export MARIADB_VERSION=10.4.32; \
  export DISTRO=deb10; \
  export BASE_URL=https://archive.mariadb.org/mariadb-${MARIADB_VERSION}/repo/debian/pool/main/m/mariadb-10.4; \
  mkdir -p /tmp/mariadb && cd /tmp/mariadb && \
  curl -LO ${BASE_URL}/mariadb-common_${MARIADB_VERSION}+maria~${DISTRO}_all.deb && \
  curl -LO ${BASE_URL}/libmariadb3_${MARIADB_VERSION}+maria~${DISTRO}_${PLATFORM}.deb && \
  curl -LO ${BASE_URL}/mariadb-client-core-10.4_${MARIADB_VERSION}+maria~${DISTRO}_${PLATFORM}.deb && \
  curl -LO ${BASE_URL}/mariadb-client-10.4_${MARIADB_VERSION}+maria~${DISTRO}_${PLATFORM}.deb && \
  curl -LO ${BASE_URL}/mariadb-server-core-10.4_${MARIADB_VERSION}+maria~${DISTRO}_${PLATFORM}.deb && \
  curl -LO ${BASE_URL}/mariadb-server-10.4_${MARIADB_VERSION}+maria~${DISTRO}_${PLATFORM}.deb && \
  dpkg -i *.deb || apt-get install -f -y && \
  apt-mark hold mariadb-server mariadb-client && \
  rm -rf /var/lib/apt/lists/* /tmp/mariadb

# Copy frontend build output
COPY --from=frontend-builder /build/dist/mempool /var/www/mempool

# Copy frontend runtime scripts from docker context
COPY mempool/docker/frontend/entrypoint.sh /patch/entrypoint.sh
COPY mempool/docker/frontend/wait-for /patch/wait-for
RUN chmod +x /patch/entrypoint.sh /patch/wait-for

# Copy nginx configs from source
COPY mempool/nginx.conf /etc/nginx/
COPY mempool/nginx-mempool.conf /etc/nginx/conf.d/

# Copy backend build output
COPY --from=backend-builder /build/package /backend/package/
COPY mempool/docker/backend/mempool-config.json /backend/
COPY mempool/docker/backend/start.sh /backend/
COPY mempool/docker/backend/wait-for-it.sh /backend/
RUN chmod +x /backend/start.sh /backend/wait-for-it.sh

# BUILD S9 CUSTOM
ADD ./docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh
ADD assets/utils/*.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh
RUN mkdir -p /usr/local/bin/migrations
ADD ./scripts/migrations/*.sh /usr/local/bin/migrations
RUN chmod a+x /usr/local/bin/migrations/*

# remove so we can manually handle db initialization
RUN rm -rf /var/lib/mysql/

WORKDIR /backend
