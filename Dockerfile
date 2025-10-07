FROM ghcr.io/gsmlg-dev/phoenix:alpine AS builder

ARG MIX_ENV=prod
ARG NAME=gsmlg_app_backend
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

RUN mix deps.get && bun install

RUN install -m 755 -D $MIX_TAILWIND_PATH /build/_build/tailwind-linux-x64 && install -m 755 -D $MIX_BUN_PATH /build/_build/bun

RUN bash update_version.sh $RELEASE_VERSION

RUN mix release "${NAME}" --version "${RELEASE_VERSION}" --overwrite

RUN cp -r "_build/prod/rel/${NAME}" /app

FROM ghcr.io/gsmlg-dev/alpine:latest

ARG MIX_ENV=prod
ARG NAME=gsmlg_app_backend
ARG RELEASE_VERSION=1.0.0

LABEL maintainer="Jonathan Gao <gsmlg.com@gmail.com>"
LABEL RELEASE_VERSION="${RELEASE_VERSION}"

ENV PORT=4152 \
    REPLACE_OS_VARS=true \
    ERL_EPMD_PORT=4369 \
    ERLCOOKIE=erlang_cookie \
    DATABASE_URL=ecto://USER:PASS@HOST/DATABASE \
    POOL_SIZE=10 \
    SECRET_KEY_BASE=${NAME}

ENV PATH=/app/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY --from=builder /app /app
COPY --from=builder /usr/bin/bun /usr/bin/bun

CMD ["/app/bin/${NAME}", "start"]
