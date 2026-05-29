#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

source .env

echo "[health] docker compose services"
docker compose ps

echo "[health] GitLab"
curl -k -I "https://${GITLAB_HOST}" | sed -n '1,8p'

echo "[health] Bit scope server"
curl -k -I "https://${BIT_HOST}" | sed -n '1,8p'

echo "[health] Bit Cloud registry proxy"
curl -k -I "https://${NPM_HOST}" | sed -n '1,8p'
