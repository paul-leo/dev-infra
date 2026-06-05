# Operations

## Start / Stop

```bash
docker compose up -d      # Start all services
docker compose down        # Stop all services
docker compose restart     # Restart all services
```

## Logs

```bash
docker compose logs -f             # All services
docker compose logs -f gitlab      # GitLab only
docker compose logs -f bit         # Bit only
docker compose logs -f verdaccio   # Verdaccio only
```

## Health Check

```bash
./scripts/healthcheck.sh
```

## Backup

```bash
./scripts/backup.sh
```

Creates a timestamped backup in `backups/` containing:
- GitLab application backup
- GitLab config
- Bit scope data

## Restore

1. Stop services: `docker compose down`
2. Extract backup archive into `data/`
3. For GitLab: copy the backup tar into `data/gitlab/data/backups/`, then:

```bash
docker compose up -d gitlab
docker compose exec gitlab gitlab-backup restore BACKUP=<timestamp>
docker compose restart
```

Always test restores on a disposable machine before relying on them.

## Upgrade

1. Check upstream release notes for breaking changes
2. Run `./scripts/backup.sh`
3. Update image tags in `.env`
4. Pull and restart:

```bash
docker compose pull
docker compose up -d
```

5. Run `./scripts/healthcheck.sh` to verify
