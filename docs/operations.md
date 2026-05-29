# Operations

## Start

```bash
cp .env.example .env
docker compose up -d
```

## Logs

```bash
docker compose logs -f caddy
docker compose logs -f gitlab
docker compose logs -f verdaccio
```

## Health Check

```bash
./scripts/healthcheck.sh
```

## Bit Service

The Bit service is intentionally a placeholder in the first scaffold.

Before wiring it behind `bit.internal.local`, define:

- service image or deployment method
- persistent data directories
- backup and restore process
- private scope creation
- package registry URL
- authentication model
- package content hardening checklist

## Stop

```bash
docker compose down
```

## Upgrade

1. Read upstream release notes.
2. Backup.
3. Change image tag in `docker-compose.yml`.
4. Run `docker compose pull`.
5. Run `docker compose up -d`.
6. Run health checks.
