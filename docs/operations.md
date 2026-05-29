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
docker compose logs -f bit
```

## Health Check

```bash
./scripts/healthcheck.sh
```

## Bit Service

The self-hosted Bit scope server is available on `https://bit.internal.local`.

The Bit Cloud registry proxy is available on `https://npm.internal.local`.

Before broad internal use, verify:

- scope creation flow
- persistent data directories
- backup and restore process
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
