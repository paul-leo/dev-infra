# Operations

## Start / Stop

```bash
# Start with current COMPOSE_PROFILES
docker compose up -d

# Start specific profiles
docker compose --profile gitlab --profile caddy up -d

# Stop all services
docker compose --profile all down

# Restart one service
docker compose restart verdaccio
```

## Logs

```bash
docker compose logs -f               # All running services
docker compose logs -f gitlab         # GitLab
docker compose logs -f verdaccio      # Verdaccio
docker compose logs -f harness        # Harness-FE
docker compose logs -f caddy          # Caddy
docker compose logs -f bit            # Bit
```

## Health Check

```bash
./scripts/healthcheck.sh
```

## Service Status

```bash
docker compose ps
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
```

## Backup

```bash
./scripts/backup.sh
```

Creates a timestamped backup in `backups/` containing:
- GitLab application backup
- GitLab config
- Bit scope data
- Verdaccio storage

## Restore

1. Stop services: `docker compose --profile all down`
2. Extract backup archive into `data/`
3. For GitLab:

```bash
# Copy backup tar into GitLab's backup directory
cp backups/<timestamp>/gitlab_backup.tar data/gitlab/data/backups/

docker compose --profile gitlab up -d gitlab
docker compose exec gitlab gitlab-backup restore BACKUP=<timestamp>
docker compose --profile gitlab restart
```

Always test restores on a disposable machine first.

## Upgrade

1. Check upstream release notes for breaking changes
2. Run `./scripts/backup.sh`
3. Update image tags in `.env`:

```env
GITLAB_IMAGE=gitlab/gitlab-ce:17.12.0-ce.0
GITLAB_RUNNER_IMAGE=gitlab/gitlab-runner:v17.12.0
```

4. Pull and restart:

```bash
docker compose pull
docker compose up -d
```

5. Verify: `./scripts/healthcheck.sh`

## Resource Usage

```bash
# Container resource usage
docker stats --no-stream

# Disk usage
du -sh data/*
docker system df
```

## Cleanup

```bash
# Remove unused Docker resources
docker system prune -f

# Remove old logs (GitLab)
docker compose exec gitlab find /var/log/gitlab -name "*.log.*" -mtime +7 -delete
```

## Caddy Certificate Management

```bash
# View active certificates
docker compose exec caddy caddy list-certificates

# Force certificate renewal
docker compose restart caddy

# Extract internal CA root cert (for trusting self-signed)
docker compose cp caddy:/data/caddy/pki/authorities/local/root.crt ./caddy-root.crt
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| GitLab slow to start | Normal on first boot (3-5 min). Check: `docker compose logs -f gitlab` |
| Port conflict | Change `*_PORT` in `.env`, then `docker compose up -d` |
| Caddy 502 | Backend service not yet ready. Wait or check service logs |
| Caddy cert error | For `.local` domains, trust the internal CA (see [ssl.md](ssl.md)) |
| Out of disk | `docker system prune -f` and clean old backups |
| Permission denied | Check `data/` directory ownership matches container UID |
