FROM gsmlg/alpine:latest

ARG RELEASE_VERSION=1.0.0

LABEL maintainer="Jonathan Gao <gsmlg.com@gmail.com>"
LABEL RELEASE_VERSION="${RELEASE_VERSION}"

ENV PORT=4152 \
    REPLACE_OS_VARS=true \
    ERL_EPMD_PORT=4369 \
    ERLCOOKIE=erlang_cookie \
    DATABASE_URL=ecto://USER:PASS@HOST/DATABASE \
    POOL_SIZE=10 \
    SECRET_KEY_BASE=gsmlg_app

ENV PATH=/app/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY ./gsmlg_app_web /app

EXPOSE 4152

CMD ["/app/bin/gsmlg_app", "start"]
