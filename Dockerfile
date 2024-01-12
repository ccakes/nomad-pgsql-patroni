ARG GO_VERSION=1.19
ARG PG_MAJOR=16
ARG TIMESCALEDB_MAJOR=2
ARG POSTGIS_MAJOR=3

############################
# Build tools binaries in separate image
############################
FROM golang:${GO_VERSION} AS tools

RUN mkdir -p ${GOPATH}/src/github.com/timescale/ \
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
# Build Postgres extensions
############################
FROM postgres:16.1 AS ext_build
ARG PG_MAJOR

RUN set -x \
    && apt-get update -y \
    && apt-get install -y git curl apt-transport-https ca-certificates build-essential libpq-dev postgresql-server-dev-${PG_MAJOR} \
    && mkdir /build \
    && cd /build \
    \
    # Build pgvector
    && git clone --branch v0.5.1 https://github.com/ankane/pgvector.git \
    && cd pgvector \
    && make \
    && make install \
    && cd .. \
    \
    # Build postgres-json-schema
    && git clone https://github.com/gavinwahl/postgres-json-schema \
    && cd postgres-json-schema \
    && make \
    && make install \
    \
    # Download pg_idkit
    && curl -LO https://github.com/VADOSWARE/pg_idkit/releases/download/v0.2.1/pg_idkit-0.2.1-pg16-gnu.tar.gz \
    && tar xf pg_idkit-0.2.1-pg16-gnu.tar.gz \
    && cp -r pg_idkit-0.2.1/lib/postgresql/* /usr/lib/postgresql/16/lib/ \
    && cp -r pg_idkit-0.2.1/share/postgresql/extension/* /usr/share/postgresql/16/extension/

############################
# Add Timescale, PostGIS and Patroni
############################
FROM postgres:16.1
ARG PG_MAJOR
ARG POSTGIS_MAJOR
ARG TIMESCALEDB_MAJOR

# Add extensions
COPY --from=tools /go/bin/* /usr/local/bin/
COPY --from=ext_build /usr/share/postgresql/16/ /usr/share/postgresql/16/
COPY --from=ext_build /usr/lib/postgresql/16/ /usr/lib/postgresql/16/

RUN set -x \
    && apt-get update -y \
    && apt-get install -y gcc curl procps python3-dev libpython3-dev libyaml-dev apt-transport-https ca-certificates \
    && echo "deb https://packagecloud.io/timescale/timescaledb/debian/ bookworm main" > /etc/apt/sources.list.d/timescaledb.list \
    && curl -L https://packagecloud.io/timescale/timescaledb/gpgkey | apt-key add - \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
        postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
        postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR-scripts \
        timescaledb-$TIMESCALEDB_MAJOR-postgresql-$PG_MAJOR \
        postgis \
        postgresql-$PG_MAJOR-pgrouting \
        postgresql-$PG_MAJOR-cron \
    \
    # Install Patroni
    && apt-get install -y --no-install-recommends patroni python3-consul \
    \
    # Install WAL-G
    && curl -LO https://github.com/wal-g/wal-g/releases/download/v2.0.1/wal-g-pg-ubuntu-20.04-amd64 \
    && install -oroot -groot -m755 wal-g-pg-ubuntu-20.04-amd64 /usr/local/bin/wal-g \
    && rm wal-g-pg-ubuntu-20.04-amd64 \
    \
    # Install vaultenv
    && curl -LO https://github.com/channable/vaultenv/releases/download/v0.15.1/vaultenv-0.15.1-linux-musl \
    && install -oroot -groot -m755 vaultenv-0.15.1-linux-musl /usr/bin/vaultenv \
    && rm vaultenv-0.15.1-linux-musl \
    \
    # Cleanup
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./files/000_shared_libs.sh /docker-entrypoint-initdb.d/000_shared_libs.sh
COPY ./files/001_initdb_postgis.sh /docker-entrypoint-initdb.d/001_initdb_postgis.sh
# COPY ./files/002_timescaledb_tune.sh /docker-entrypoint-initdb.d/002_timescaledb_tune.sh

COPY ./files/update-postgis.sh /usr/local/bin
COPY ./files/docker-initdb.sh /usr/local/bin

USER postgres
CMD ["patroni", "/secrets/patroni.yml"]
