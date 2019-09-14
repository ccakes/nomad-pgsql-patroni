# nomad-pgsql-patroni

A simple container running Alpine, Postgres and Patroni useful for dropping directly into a Hashicorp environment (Nomad + Consul + Vault)

It also contains some helpers for ongoing maintenance

- **awscli**<br />
  So the same container image can be used in backup jobs
- **wal-g**<br />
  See here for more info - https://github.com/wal-g/wal-g
- **timescaledb**<br />
  See here for more info - https://github.com/timescale/timescaledb

## Usage
```hcl
# main.tf
resource "nomad_job" "postgres" {
  jobspec = "${file("${path.module}/job.hcl")}"
}

# job.hcl
task "your-task" {
  type = "service"
  dataceners = ["default"]

  vault { policies = ["postgres"] }

  group "your-group" {
    count = 3

    task "db" {
      driver = "docker"

      template {
        data <<EOL
scope: postgres
name: pg-{{env "node.unique.name"}}
namespace: /nomad

restapi:
  listen: 0.0.0.0:{{env "NOMAD_PORT_api"}}
  connect_address: {{env "NOMAD_ADDR_api"}}

consul:
host: consul.example.com
token: {{with secret "consul/creds/postgres"}}{{.Data.token}}{{end}}
register_service: true

# bootstrap config
EOL
      }

      config {
        image = "ccakes/nomad-pgsql-patroni:11.5-2.tsdb"

        port_map {
          pg = 5432
          api = 8008
        }
      }

      resources {
        memory = 1024

        network {
          port "api" {}
          port "pg" {}
        }
      }
    }
  }
}
```
