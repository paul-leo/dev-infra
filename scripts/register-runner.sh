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

# Use internal Docker network hostname so runner can reach GitLab from within its container.
# --clone-url overrides the repo clone URL for pipeline jobs (also uses internal network).
docker compose exec gitlab-runner gitlab-runner register \
  --non-interactive \
  --url http://gitlab \
  --token "$TOKEN" \
  --executor docker \
  --docker-image alpine:latest \
  --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
  --clone-url http://gitlab \
  --description "local-docker-runner"

echo ""
echo "Runner registered. Config saved to data/gitlab-runner/config/config.toml"
