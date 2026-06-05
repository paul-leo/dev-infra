#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

source .env

echo "[health] docker compose services"
docker compose ps

GITLAB_URL="${GITLAB_EXTERNAL_URL:-http://localhost:${GITLAB_PORT:-9080}}"
BIT_URL="http://${HOST_IP:-127.0.0.1}:${BIT_PORT:-9030}"
VERDACCIO_URL="http://${HOST_IP:-127.0.0.1}:${VERDACCIO_PORT:-9040}"
HARNESS_URL="http://${HOST_IP:-127.0.0.1}:${HARNESS_PORT:-9050}"

echo "[health] GitLab"
curl -sS -o /dev/null -w "  HTTP %{http_code} (%{time_total}s)\n" "$GITLAB_URL" || echo "  UNREACHABLE"

echo "[health] Bit scope server"
curl -sS -o /dev/null -w "  HTTP %{http_code} (%{time_total}s)\n" "$BIT_URL" || echo "  UNREACHABLE"

echo "[health] Verdaccio (npm registry)"
curl -sS -o /dev/null -w "  HTTP %{http_code} (%{time_total}s)\n" "$VERDACCIO_URL" || echo "  UNREACHABLE"

echo "[health] Harness-FE gateway"
curl -sS -o /dev/null -w "  HTTP %{http_code} (%{time_total}s)\n" "$HARNESS_URL" || echo "  UNREACHABLE"
