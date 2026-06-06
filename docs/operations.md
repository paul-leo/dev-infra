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

Caddy is mode-aware — the `AUTO_HTTPS` and `TLS_SNIPPET` env vars in `.env`
control which TLS strategy it uses. See [docs/ssl.md](ssl.md) for the full
walkthrough of the four supported modes (plain HTTP / Let's Encrypt /
internal CA / custom cert).

```bash
# View active certificates (modes 2/3/4 only)
docker compose exec caddy caddy list-certificates

# Force certificate renewal (Let's Encrypt)
docker compose restart caddy

# Extract Caddy's internal root CA (mode 3 — trust this on clients)
docker compose cp caddy:/data/caddy/pki/authorities/local/root.crt ./caddy-root.crt

# Wipe stale certs after switching modes
docker compose down
rm -rf data/caddy
docker compose up -d caddy
```

## Testing

The project ships a [bats](https://github.com/bats-core/bats-core) test suite
under `tests/`. It catches the things that fail silently in CI — bad YAML,
drifted ports, missing env vars, broken Caddyfile modes, leaked secrets.

### Install bats

```bash
# macOS
brew install bats-core

# Ubuntu / Debian
sudo apt-get install -y bats
```

### Run the suite

```bash
# Static + lightweight (no Docker required)
bash tests/run-all.sh

# + Pull caddy image, validate every TLS mode in a real container
RUN_INTEGRATION=1 bash tests/run-all.sh

# + Full smoke test (docker compose up + health endpoints)
RUN_SMOKE=1 bash tests/run-all.sh
```

| Layer | What it covers | Always runs? |
|-------|----------------|:------------:|
| `01-compose-syntax` | `docker compose config` for every profile, env var presence, port symmetry | ✅ |
| `02-caddyfile-render` | Caddyfile renders for each domain, snippet declarations match imports, `caddy adapt` + `caddy validate` in `caddy:2-alpine` | Static: ✅ / Container: `RUN_INTEGRATION=1` |
| `03-port-consistency` | `CADDY_HTTP_PORT` / `CADDY_HTTPS_PORT` drive host, container, and Caddy's `http_port` / `https_port` from one source | ✅ |
| `04-config-quality` | `.env` not committed, `.gitignore` covers `data/`, no hardcoded passwords, Caddyfile snippet names declared | ✅ |
| `05-smoke` | Brings up `verdaccio + harness`, checks health. Caddy in `tls-none` and `tls-internal` modes starts and serves | `RUN_SMOKE=1` |

The test runner prints a banner showing which layers are enabled:

```
╔═══════════════════════════════════════════════════════════════╗
║  dev-infra test suite                                          ║
║  Static + lightweight  : always                               ║
║  Integration (caddy)   : ENABLED                              ║
║  Smoke (full bring-up) : skipped (set RUN_SMOKE=1)            ║
╚═══════════════════════════════════════════════════════════════╝
```

### CI

`.github/workflows/test.yml` runs on every push and PR:

- **Static job** — every push / PR
- **Integration job** — every push to main, on manual dispatch, or on PRs labelled `integration`
- **Smoke job** — only on manual dispatch (the workflow_dispatch input)

Trigger a smoke run from the GitHub UI: *Actions → tests → Run workflow*.

### Adding a new test

Create a file in `tests/` named `NN-description.bats` (the `NN-` prefix
determines run order). Load shared helpers with `load 'helpers'`.

```bash
@test "my new assertion" {
    run my_command
    [ "$status" -eq 0 ]
}
```

See the [bats documentation](https://bats-core.readthedocs.io/) for the
full assertion API.



Caddy is mode-aware — the `AUTO_HTTPS` and `TLS_SNIPPET` env vars in `.env`
control which TLS strategy it uses. See [docs/ssl.md](ssl.md) for the full
walkthrough of the four supported modes (plain HTTP / Let's Encrypt /
internal CA / custom cert).

```bash
# View active certificates (modes 2/3/4 only)
docker compose exec caddy caddy list-certificates

# Force certificate renewal (Let's Encrypt)
docker compose restart caddy

# Extract Caddy's internal root CA (mode 3 — trust this on clients)
docker compose cp caddy:/data/caddy/pki/authorities/local/root.crt ./caddy-root.crt

# Wipe stale certs after switching modes
docker compose down
rm -rf data/caddy
docker compose up -d caddy
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| GitLab slow to start | Normal on first boot (3-5 min). Check: `docker compose logs -f gitlab` |
| Port conflict | Change `*_PORT` in `.env`, then `docker compose up -d` |
| Caddy 502 | Backend service not yet ready. Wait or check service logs |
| Caddy cert error | Trust the CA per [ssl.md](ssl.md), or check `AUTO_HTTPS` / `TLS_SNIPPET` |
| Wrong TLS mode | Edit `AUTO_HTTPS` / `TLS_SNIPPET` in `.env`, then `docker compose restart caddy` |
| Stale certs after mode switch | `docker compose down && rm -rf data/caddy && docker compose up -d caddy` |
| Out of disk | `docker system prune -f` and clean old backups |
| Permission denied | Check `data/` directory ownership matches container UID |
