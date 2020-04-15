#!/usr/bin/env bash
echo "timezone = 'UTC'" >> $PGDATA/postgresql.conf

echo "shared_preload_libraries = 'pg_stat_statements, timescaledb'" >> $PGDATA/postgresql.conf

echo "pg_stat_statements.max = 10000" >> $PGDATA/postgresql.conf
echo "pg_stat_statements.track = all" >> $PGDATA/postgresql.conf

echo "timescaledb.telemetry_level = off" >> $PGDATA/postgresql.conf
