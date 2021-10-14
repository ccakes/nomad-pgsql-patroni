ARG GO_VERSION=1.17.0
ARG PG_MAJOR=14
ARG TIMESCALEDB_MAJOR=2
ARG POSTGIS_MAJOR=3

############################
# Build Postgres extensions
############################
FROM postgres:14.0 AS ext_build
ARG PG_MAJOR

RUN set -x \
    && apt-get update -y \
    && apt-get install -y git curl apt-transport-https ca-certificates build-essential libpq-dev postgresql-server-dev-${PG_MAJOR} \
    && mkdir /build \
    && cd /build \
    \
    # Build pgvector
    && git clone --branch v0.1.6 https://github.com/ankane/pgvector.git \
    && cd pgvector \
    && make \
    && make install \
    && cd .. \
    \
    # Build postgres-json-schema
    && git clone https://github.com/gavinwahl/postgres-json-schema \
    && cd postgres-json-schema \
    && make \
    && make install

############################
# Add Timescale, PostGIS and Patroni
############################
FROM postgres:14.0
ARG PG_MAJOR
ARG POSTGIS_MAJOR

# Add extensions
COPY --from=ext_build /usr/share/postgresql/14/ /usr/share/postgresql/14/
COPY --from=ext_build /usr/lib/postgresql/14/ /usr/lib/postgresql/14/

RUN set -x \
    && apt-get update -y \
    && apt-get install -y gcc curl procps python3-dev libpython3-dev libyaml-dev apt-transport-https ca-certificates \
    && apt-get update -y \
    && apt-cache showpkg postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
    && apt-get install -y --no-install-recommends \
        postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
        postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR-scripts \
        postgis \
        postgresql-$PG_MAJOR-pgrouting \
    \
    # Install Patroni
    && apt-get install -y --no-install-recommends \
        python3 python3-pip python3-setuptools \
    && pip3 install --upgrade pip \
    && pip3 install wheel zipp==1.0.0 \
    && pip3 install awscli python-consul psycopg2-binary \
    && pip3 install https://github.com/zalando/patroni/archive/v2.1.1.zip \
    \
    # Install WAL-G
    && curl -LO https://github.com/wal-g/wal-g/releases/download/v1.1/wal-g-pg-ubuntu-20.04-amd64 \
    && install -oroot -groot -m755 wal-g-pg-ubuntu-20.04-amd64 /usr/local/bin/wal-g \
    && rm wal-g-pg-ubuntu-20.04-amd64 \
    \
    # Install vaultenv
    && curl -LO https://github.com/channable/vaultenv/releases/download/v0.13.3/vaultenv-0.13.3-linux-musl \
    && install -oroot -groot -m755 vaultenv-0.13.3-linux-musl /usr/bin/vaultenv \
    && rm vaultenv-0.13.3-linux-musl \
    \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* \
    \
    # Add postgres to root group so it can read a private key for TLS
    # See https://github.com/hashicorp/nomad/issues/5020
    && gpasswd -a postgres root

RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./files/000_shared_libs.sh /docker-entrypoint-initdb.d/000_shared_libs.sh
COPY ./files/001_initdb_postgis.sh /docker-entrypoint-initdb.d/001_initdb_postgis.sh
# COPY ./files/002_timescaledb_tune.sh /docker-entrypoint-initdb.d/002_timescaledb_tune.sh

COPY ./files/update-postgis.sh /usr/local/bin
COPY ./files/docker-initdb.sh /usr/local/bin

USER postgres
CMD ["patroni", "/secrets/patroni.yml"]
