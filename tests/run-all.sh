#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run-all.sh — local automated test runner
#
# Runs every .bats file under tests/ in lexical order. Exits non-zero on the
# first failure. Skip the heavy integration / smoke tests by default — opt in
# with the env vars below.
#
# Usage:
#   bash tests/run-all.sh                       # static + lightweight only
#   RUN_INTEGRATION=1 bash tests/run-all.sh      # + pull caddy image, validate each mode
#   RUN_SMOKE=1        bash tests/run-all.sh      # + full docker compose up + health
#
# Requirements:
#   - bats-core    (brew install bats-core / apt install bats)
#   - docker       (for integration / smoke)
#   - docker compose v2
#
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$ROOT_DIR/tests"

# ─── Pre-flight ──────────────────────────────────────────────────────────────
if ! command -v bats >/dev/null 2>&1; then
	cat >&2 <<EOF
ERROR: bats-core is not installed.

Install it with:
  macOS:   brew install bats-core
  Ubuntu:  sudo apt-get install -y bats
  Other:   https://github.com/bats-core/bats-core

Then re-run: bash tests/run-all.sh
EOF
	exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
	echo "WARNING: docker not found. Integration / smoke tests will be skipped." >&2
	export SKIP_DOCKER=1
fi

# ─── Banner ──────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  dev-infra test suite                                          ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  Static + lightweight  : always                               ║"
[[ -n "${RUN_INTEGRATION:-}" ]] && echo "║  Integration (caddy)   : ENABLED                              ║" \
	|| echo "║  Integration (caddy)   : skipped (set RUN_INTEGRATION=1)      ║"
[[ -n "${RUN_SMOKE:-}" ]] && echo "║  Smoke (full bring-up) : ENABLED                              ║" \
	|| echo "║  Smoke (full bring-up) : skipped (set RUN_SMOKE=1)            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# ─── Run ─────────────────────────────────────────────────────────────────────
cd "$ROOT_DIR"
bats --print-output-on-failure --recursive "$TESTS_DIR"
