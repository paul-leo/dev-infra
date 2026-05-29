#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$ROOT_DIR/backups/$STAMP"

mkdir -p "$BACKUP_DIR"

echo "[backup] creating GitLab application backup"
docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T gitlab gitlab-backup create

echo "[backup] archiving config and registry data"
tar -C "$ROOT_DIR" -czf "$BACKUP_DIR/config-and-verdaccio.tgz" \
  .env \
  caddy \
  verdaccio \
  data/gitlab/config \
  data/verdaccio

echo "[backup] done: $BACKUP_DIR"

