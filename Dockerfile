############################
# Build tools binaries in separate image
############################
ARG GO_VERSION=1.12.7
FROM golang:${GO_VERSION}-alpine AS tools

ENV TOOLS_VERSION 0.7.0

RUN apk update && apk add --no-cache git \
    && mkdir -p ${GOPATH}/src/github.com/timescale/ \
    && cd ${GOPATH}/src/github.com/timescale/ \
    && git clone https://github.com/timescale/timescaledb-tune.git \
    && git clone https://github.com/timescale/timescaledb-parallel-copy.git \
    # Build timescaledb-tune
    && cd timescaledb-tune/cmd/timescaledb-tune \
    && git fetch && git checkout --quiet $(git describe --abbrev=0) \
    && go get -d -v \
    && go build -o /go/bin/timescaledb-tune \
    # Build timescaledb-parallel-copy
    && cd ${GOPATH}/src/github.com/timescale/timescaledb-parallel-copy/cmd/timescaledb-parallel-copy \
    && git fetch && git checkout --quiet $(git describe --abbrev=0) \
    && go get -d -v \
    && go build -o /go/bin/timescaledb-parallel-copy

############################
# Final image with Patroni
############################
FROM postgres:11.5-alpine

RUN  set -ex \
  && addgroup postgres root \
  && apk add --no-cache --virtual .fetch-deps \
    ca-certificates \
    curl \
    git \
    openssl \
    openssl-dev \
    tar \
  && mkdir -p /build/ \
  && git clone https://github.com/timescale/timescaledb /build/timescaledb \
  \
  && apk add --no-cache --virtual .build-deps \
    coreutils \
    dpkg-dev dpkg \
    gcc \
    libc-dev \
    make \
    cmake \
    python3-dev \
    musl-dev \
    linux-headers \
    util-linux-dev \
  \
  # Install Patroni
  && apk add --no-cache python3 \
  && pip3 install awscli python-consul \
  && pip3 install psycopg2-binary \
  # && pip3 install https://github.com/ccakes/patroni/archive/master.zip \
  && pip3 install https://github.com/zalando/patroni/archive/v1.6.0.zip \
  \
  # Install WAL-G
  && curl -LO https://github.com/wal-g/wal-g/releases/download/v0.2.12/wal-g.linux-amd64.tar.gz \
  && tar xf wal-g.linux-amd64.tar.gz \
  && rm -f wal-g.linux-amd64.tar.gz \
  && mv wal-g /usr/local/bin/ \
  \
  # Install Timescale
  # Build current version \
  && cd /build/timescaledb && rm -fr build \
  && git checkout ${TIMESCALEDB_VERSION} \
  && ./bootstrap -DPROJECT_INSTALL_METHOD="docker" -DAPACHE_ONLY=1 -DREGRESS_CHECKS=OFF \
  && cd build && make install \
  && cd ~ \
  \
  # Clean up
  && apk del .fetch-deps .build-deps \
  && rm -rf /build \
  && ls -l /usr/share/ \
  && cp /usr/local/share/postgresql/postgresql.conf.sample /var/lib/postgresql/postgresql.conf \
  && touch /var/lib/postgresql/pg_hba.conf \
  && mkdir -p /run/postgresql \
  && chown -R postgres.postgres /var/lib/postgresql /run/postgresql

EXPOSE 8008
EXPOSE 5432

USER postgres
CMD ["patroni", "/secrets/patroni.yml"]
