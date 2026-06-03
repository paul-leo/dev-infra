#!/usr/bin/env sh
# Register GitLab Runner with the local GitLab instance.
# Run once after GitLab is up and you have a runner registration token.
#
# Usage:
#   ./scripts/register-runner.sh <REGISTRATION_TOKEN>
#
# Get the token from:
#   GitLab → Admin Area → CI/CD → Runners → New instance runner → copy token

set -eu

TOKEN="${1:-}"
if [ -z "$TOKEN" ]; then
  echo "Usage: $0 <REGISTRATION_TOKEN>"
  exit 1
fi

# Load HOST_IP and GITLAB_PORT from .env if present
if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -a; . ./.env; set +a
fi

GITLAB_URL="${GITLAB_EXTERNAL_URL:-http://localhost:8080}"

docker compose exec gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "$GITLAB_URL" \
  --token "$TOKEN" \
  --executor docker \
  --docker-image alpine:latest \
  --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
  --description "local-docker-runner" \
  --run-untagged true \
  --locked false

echo ""
echo "Runner registered. Config saved to data/gitlab-runner/config/config.toml"
