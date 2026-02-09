# Multi-stage Dockerfile for building three release types:
# - gsmlg_app_backend (full): tag 1.0.0
# - gsmlg_app_admin: tag 1.0.0-admin
# - gsmlg_app (public): tag 1.0.0-public
#
# Build examples:
#   docker build --target backend -t gsmlg-app-backend:1.0.0 .
#   docker build --target admin -t gsmlg-app-backend:1.0.0-admin .
#   docker build --target public -t gsmlg-app-backend:1.0.0-public .

# =============================================================================
# Builder stage: compiles all releases
# =============================================================================
FROM ghcr.io/gsmlg-dev/phoenix:alpine AS builder

ARG MIX_ENV=prod
ARG RELEASE_VERSION=1.0.0

ARG http_proxy
ARG https_proxy

ARG NPM_CONFIG_REGISTRY
ARG HEX_MIRROR

ARG MIX_TAILWIND_PATH=/usr/bin/tailwind
ARG MIX_BUN_PATH=/usr/bin/bun

ARG XLA_BUILD=true

ARG TARGETARCH

COPY . /build

WORKDIR /build

# Install build dependencies for native code compilation (picosat_elixir, etc.)
# Create sys/unistd.h symlink for musl compatibility (picosat_elixir expects glibc path)
RUN apk add --no-cache musl-dev linux-headers && \
    mkdir -p /usr/include/sys && \
    ln -sf /usr/include/unistd.h /usr/include/sys/unistd.h

RUN mix deps.get && bun install

RUN install -m 755 -D $MIX_TAILWIND_PATH /build/_build/tailwind-linux-x64 && \
    install -m 755 -D $MIX_BUN_PATH /build/_build/bun

RUN bash update_version.sh $RELEASE_VERSION

# Build all three releases
RUN mix release gsmlg_app_backend --version "${RELEASE_VERSION}" --overwrite && \
    mix release gsmlg_app_admin --version "${RELEASE_VERSION}" --overwrite && \
    mix release gsmlg_app --version "${RELEASE_VERSION}" --overwrite

# =============================================================================
# Runtime base: common runtime configuration
# =============================================================================
FROM ghcr.io/gsmlg-dev/alpine:latest AS runtime-base

ARG RELEASE_VERSION=1.0.0

LABEL maintainer="Jonathan Gao <gsmlg.com@gmail.com>"
LABEL RELEASE_VERSION="${RELEASE_VERSION}"

ENV REPLACE_OS_VARS=true \
    ERL_EPMD_PORT=4369 \
    ERLCOOKIE=erlang_cookie \
    DATABASE_URL=ecto://USER:PASS@HOST/DATABASE \
    POOL_SIZE=10

ENV PATH=/app/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY --from=builder /usr/bin/bun /usr/bin/bun

# =============================================================================
# Backend: Full release with all applications (ports 4152, 4153)
# =============================================================================
FROM runtime-base AS backend

ENV PORT=4152 \
    SECRET_KEY_BASE=gsmlg_app_backend

COPY --from=builder /build/_build/prod/rel/gsmlg_app_backend /app

EXPOSE 4152 4153

CMD ["/app/bin/gsmlg_app_backend", "start"]

# =============================================================================
# Admin: Admin-only release (port 4153)
# =============================================================================
FROM runtime-base AS admin

ENV PORT=4153 \
    SECRET_KEY_BASE=gsmlg_app_admin

COPY --from=builder /build/_build/prod/rel/gsmlg_app_admin /app

EXPOSE 4153

CMD ["/app/bin/gsmlg_app_admin", "start"]

# =============================================================================
# Public: Public app release (port 4152)
# =============================================================================
FROM runtime-base AS public

ENV PORT=4152 \
    SECRET_KEY_BASE=gsmlg_app

COPY --from=builder /build/_build/prod/rel/gsmlg_app /app

EXPOSE 4152

CMD ["/app/bin/gsmlg_app", "start"]
