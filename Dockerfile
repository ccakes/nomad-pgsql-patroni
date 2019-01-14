FROM alpine

RUN  set -ex \
  && apk -U add --no-cache postgresql python3 \
  \
  && apk add --no-cache \
    postgresql-dev python3-dev gcc musl-dev linux-headers curl \
  \
  && pip3 install patroni[consul] awscli \
  \
  && curl -LO https://github.com/wal-g/wal-g/releases/download/v0.2.3/wal-g.linux-amd64.tar.gz \
  && tar xf wal-g.linux-amd64.tar.gz \
  && rm -f wal-g.linux-amd64.tar.gz \
  && mv wal-g /usr/local/bin/ \
  \
  #&& apk del .build-deps \
  \
  && ls -l /usr/share/ \
  && cp /usr/share/postgresql/postgresql.conf.sample /var/lib/postgresql/postgresql.conf \
  && touch /var/lib/postgresql/pg_hba.conf \
  && mkdir -p /run/postgresql \
  && chown -R postgres.postgres /var/lib/postgresql /run/postgresql

EXPOSE 8008
EXPOSE 5432

USER postgres
CMD ["patroni", "/secrets/patroni.yml"]
