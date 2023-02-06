# nomad-pgsql-patroni

A simple container running Postgres and Patroni useful for dropping directly into a Hashicorp environment (Nomad + Consul + Vault)

It also comes pre-baked with some tools and extensions

### Tools

| Name | Version | Link |
|--|--|--|
| awscli | 1.22.64 | https://pypi.org/project/awscli/ |
| WAL-G | 2.0.1 | https://github.com/wal-g/wal-g |
| Patroni | 3.0.0 | https://github.com/zalando/patroni |
| vaultenv | 0.15.1 | https://github.com/channable/vaultenv |

### Extensions

| Name | Version | Link |
|--|--|--|
| Timescale | 2.9.2 | https://www.timescale.com |
| PostGIS | 3.3.2 | https://postgis.net |
| pg_cron | 1.4 | https://github.com/citusdata/pg_cron |
| pgRouting | 3.4.2 | https://pgrouting.org |
| postgres-json-schema | 0.1.1 | https://github.com/gavinwahl/postgres-json-schema |
| vector | 0.4.0 | https://github.com/ankane/pgvector |

### Running another version of Postgres?

See the [`pg-12`](https://github.com/ccakes/nomad-pgsql-patroni/tree/pg-12) or [`pg-13`](https://github.com/ccakes/nomad-pgsql-patroni/tree/pg-13) branches for other Postgres versions. Otherwise, jump to [`master`](https://github.com/ccakes/nomad-pgsql-patroni) for the latest and greatest! :sparkles:

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
        image = "ccakes/nomad-pgsql-patroni:14.6-1.tsdb_gis"

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
