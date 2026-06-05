#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

source .env

echo "[health] docker compose services"
docker compose ps

GITLAB_URL="${GITLAB_EXTERNAL_URL:-http://localhost:${GITLAB_PORT:-8080}}"
BIT_URL="http://${HOST_IP:-127.0.0.1}:${BIT_PORT:-3000}"

echo "[health] GitLab"
curl -sS -o /dev/null -w "  HTTP %{http_code} (%{time_total}s)\n" "$GITLAB_URL" || echo "  UNREACHABLE"

echo "[health] Bit scope server"
curl -sS -o /dev/null -w "  HTTP %{http_code} (%{time_total}s)\n" "$BIT_URL" || echo "  UNREACHABLE"
