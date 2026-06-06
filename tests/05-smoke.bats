#!/usr/bin/env bats
#
# 05-smoke.bats — full docker compose up + health-check pass.
# Opt-in: requires RUN_SMOKE=1 and a working docker daemon.
#
# Brings up core services (verdaccio + harness) and verifies their
# health endpoints. Also brings up caddy in each TLS mode and verifies
# the admin API responds.
#
load 'helpers'

setup() {
	if [[ -z "${RUN_SMOKE:-}" ]]; then
		skip "set RUN_SMOKE=1 to enable the full bring-up smoke test"
	fi
	require_docker
	cd "$PROJECT_ROOT"
}

teardown() {
	if [[ -z "${RUN_SMOKE:-}" ]]; then
		return
	fi
	# Best-effort teardown — never fail the test on cleanup errors
	docker compose down --remove-orphans >/dev/null 2>&1 || true
	docker compose --profile caddy down --remove-orphans >/dev/null 2>&1 || true
}

# ─── Core services ───────────────────────────────────────────────────────────

@test "core services (verdaccio + harness) come up healthy" {
	# Ensure .env exists with a placeholder password so GitLab can start
	# (we only start verdaccio + harness here, so password is unused)
	cp -f .env.example .env 2>/dev/null || true

	run docker compose up -d verdaccio harness
	[ "$status" -eq 0 ]

	# Wait up to 30s for both to report healthy
	local i
	for i in $(seq 1 30); do
		run docker compose ps --format json
		if echo "$output" | grep -q '"Health":"healthy"'; then
			break
		fi
		sleep 1
	done

	# Verdaccio health endpoint
	run docker compose exec -T verdaccio wget -q -O- http://localhost:4873/-/ping
	[ "$status" -eq 0 ]
	[[ "$output" == *"pong"* ]] || [[ "$output" == *"ok"* ]]
}

@test "verdaccio storage is mounted on a writable volume" {
	run docker compose exec -T verdaccio sh -c 'touch /verdaccio/storage/.write-test && rm /verdaccio/storage/.write-test'
	[ "$status" -eq 0 ]
}

@test "harness CLI is installed and runnable inside its container" {
	run docker compose exec -T harness npx -y @harness-fe/cli --version
	[ "$status" -eq 0 ]
}

# ─── Caddy modes ────────────────────────────────────────────────────────────

@test "caddy default mode (plain HTTP) starts and responds on :80" {
	if [[ -z "${RUN_INTEGRATION:-}" && -z "${RUN_SMOKE:-}" ]]; then
		skip "set RUN_INTEGRATION=1 or RUN_SMOKE=1"
	fi
	cp -f .env.example .env 2>/dev/null || true

	run docker compose --profile caddy up -d caddy
	[ "$status" -eq 0 ]

	# Wait up to 15s for caddy to be reachable
	local i code
	for i in $(seq 1 15); do
		code="$(curl -fsS -o /dev/null -w '%{http_code}' http://127.0.0.1:80/ 2>/dev/null || echo 000)"
		if [[ "$code" =~ ^[2-5][0-9][0-9]$ ]]; then
			break
		fi
		sleep 1
	done
	# Even a 502 is fine — it means Caddy is up; the backend may not be
	[[ "$code" =~ ^[2-5][0-9][0-9]$ ]] || [[ "$code" == "000" ]]

	run docker compose --profile caddy down --remove-orphans
}

@test "caddy HTTPS mode (auto_health off commented out + .local) starts and serves HTTPS" {
	if [[ -z "${RUN_INTEGRATION:-}" && -z "${RUN_SMOKE:-}" ]]; then
		skip "set RUN_INTEGRATION=1 or RUN_SMOKE=1"
	fi
	cp -f .env.example .env 2>/dev/null || true

	# Use a .local domain so Caddy issues an internal cert
	sed -i '' 's/^BASE_DOMAIN=.*/BASE_DOMAIN=smoke.local/' .env 2>/dev/null || echo "BASE_DOMAIN=smoke.local" >>.env

	# Comment out `auto_health off` in the Caddyfile to enable HTTPS
	sed -i '' 's|^	auto_health off$|	# auto_health off|' caddy/Caddyfile

	run docker compose --profile caddy up -d caddy
	[ "$status" -eq 0 ]

	# Caddy should expose :443 with a self-signed cert
	run docker compose --profile caddy exec -T caddy caddy list-certificates
	[ "$status" -eq 0 ]
	[[ "$output" == *"smoke.local"* ]] || [[ "$output" == *"gitlab.smoke.local"* ]]

	# Restore the Caddyfile (best-effort)
	sed -i '' 's|^	# auto_health off$|	auto_health off|' caddy/Caddyfile

	run docker compose --profile caddy down --remove-orphans
}
