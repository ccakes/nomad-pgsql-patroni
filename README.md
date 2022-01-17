# nomad-pgsql-patroni

A simple container running Postgres and Patroni useful for dropping directly into a Hashicorp environment (Nomad + Consul + Vault)

It also comes pre-baked with some tools and extensions

### Tools

| Name | Version | Link |
|--|--|--|
| awscli | 1.19.91 | https://pypi.org/project/awscli/ |
| WAL-G | 1.1 | https://github.com/wal-g/wal-g |
| Patroni | 2.1.2 | https://github.com/zalando/patroni |
| vaultenv | 0.14.0 | https://github.com/channable/vaultenv |

### Extensions

| Name | Version | Link |
|--|--|--|
| Timescale | 2.4.2 | https://www.timescale.com |
| PostGIS | 3.1.4 | https://postgis.net |
| pgRouting | 3.2.1 | https://pgrouting.org |
| postgres-json-schema | 0.1.1 | https://github.com/gavinwahl/postgres-json-schema |
| vector | 0.2.2 | https://github.com/ankane/pgvector |

### A note about TimescaleDB and Postgres 14

Timescale doesn't yet support Postgres 14 so it's missing from the these builds. If you need Timescale, stick to the [`pg-13`](https://github.com/ccakes/nomad-pgsql-patroni/tree/pg-13) branch for now.

Support is tracked in https://github.com/timescale/timescaledb/issues/3034

### Still running an older Postgres version?

These branches are *mostly* supported containing older versions. If I get behind on a point release feel free to raise an issue :thumbsup:

- [`pg-13`](https://github.com/ccakes/nomad-pgsql-patroni/tree/pg-13)
- [`pg-12`](https://github.com/ccakes/nomad-pgsql-patroni/tree/pg-12)
- [`pg-11`](https://github.com/ccakes/nomad-pgsql-patroni/tree/pg-11)

## Usage

```hcl
job "postgres-14" {
  type = "service"
  datacenters = ["dc1"]

  group "group" {
    count = 1

    network {
      port api { to = 8080 }
      port pg { to = 5432 }
    }

    task "db" {
      driver = "docker"

      template {
        data = <<EOL
scope: postgres
name: pg-{{env "node.unique.name"}}
namespace: /nomad

restapi:
  listen: 0.0.0.0:{{env "NOMAD_PORT_api"}}
  connect_address: {{env "NOMAD_ADDR_api"}}

consul:
host: localhost
register_service: true

# bootstrap config
EOL

        destination = "/secrets/patroni.yml"
      }

      config {
        image = "ccakes/nomad-pgsql-patroni:14.0-1.gis"

        ports = ["api", "pg"]
      }

      resources {
        memory = 1024
      }
    }
  }
}

```

## Testing

An example `docker-compose` file and patroni config is included to see this running.
```shell
$ docker-compose -f docker-compose.test.yml up
```

## ISSUES

Postgres runs as the postgres user however that user has been added to the root group. This probably has some security ramifications that I haven't thought of, but it's required for postgres to read TLS keys generated by Vault and written as templates.

[hashicorp/nomad#5020](https://github.com/hashicorp/nomad/issues/5020) is tracking (hopefully) a fix for this.
