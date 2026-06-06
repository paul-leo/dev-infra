#!/usr/bin/env bats
#
# 02-caddyfile-render.bats — Caddyfile renders and validates for every TLS
# mode (tls-none, tls-internal, tls-custom) and the default Caddy
# auto-issue behaviour.
#
load 'helpers'

setup() {
	cd "$PROJECT_ROOT"
}

@test "Caddyfile is present" {
	[ -f "$PROJECT_ROOT/caddy/Caddyfile" ]
}

@test "Caddyfile defines a global options block" {
	run grep -E '^\{' "$PROJECT_ROOT/caddy/Caddyfile"
	[ "$status" -eq 0 ]
}

@test "Caddyfile hardcodes auto_https off (mode 1 default)" {
	assert_file_contains "$PROJECT_ROOT/caddy/Caddyfile" "auto_https off"
}

@test "Caddyfile documents the four-mode TLS strategy" {
	for marker in \
		"Mode 1: Plain HTTP" \
		"Mode 2: Public domain" \
		"Mode 3: .local" \
		"Mode 4: Custom"; do
		assert_file_contains "$PROJECT_ROOT/caddy/Caddyfile" "$marker"
	done
}

@test "Caddyfile routes gitlab.localhost → gitlab:80" {
	rendered="$(caddy_render)"
	[[ "$rendered" == *"gitlab.localhost"* ]]
	[[ "$rendered" == *"reverse_proxy gitlab:80"* ]]
}

@test "Caddyfile routes npm.localhost → verdaccio:4873" {
	rendered="$(caddy_render)"
	[[ "$rendered" == *"npm.localhost"* ]]
	[[ "$rendered" == *"reverse_proxy verdaccio:4873"* ]]
}

@test "Caddyfile routes bit.localhost → bit:3000" {
	rendered="$(caddy_render)"
	[[ "$rendered" == *"bit.localhost"* ]]
	[[ "$rendered" == *"reverse_proxy bit:3000"* ]]
}

@test "Caddyfile routes harness.localhost → harness:9050 + WS 9051" {
	rendered="$(caddy_render)"
	[[ "$rendered" == *"harness.localhost"* ]]
	[[ "$rendered" == *"reverse_proxy @websocket harness:9051"* ]]
	[[ "$rendered" == *"reverse_proxy harness:9050"* ]]
}

@test "Caddyfile contains a commented-out tls directive per site (mode 4 hint)" {
	# mode 4 (custom cert) requires the user to uncomment a tls line in each
	# of the 4 site blocks. Make sure all 4 hints are present.
	run grep -cE "^\s*#\s*tls /certs/cert\.pem /certs/key\.pem\s*#\s*mode 4" \
		"$PROJECT_ROOT/caddy/Caddyfile"
	[ "$status" -eq 0 ]
	[ "$output" -eq 4 ]
}

# ─── Container-level validation (opt-in via RUN_INTEGRATION=1) ──────────────

@test "Caddyfile (default, plain HTTP) validates in caddy:2-alpine" {
	if [[ -z "${RUN_INTEGRATION:-}" ]]; then
		skip "set RUN_INTEGRATION=1 to enable container validation"
	fi
	run caddy_validate
	[ "$status" -eq 0 ]
}

@test "Caddyfile with auto_health off REMOVED (HTTPS mode) validates" {
	if [[ -z "${RUN_INTEGRATION:-}" ]]; then
		skip "set RUN_INTEGRATION=1 to enable container validation"
	fi
	# Render, then comment out the auto_health off line to simulate mode 2/3
	local rendered
	rendered="$(caddy_render)"
	rendered="$(echo "$rendered" | sed 's|^	auto_health off|#	auto_health off|')"

	# Pipe adapt's JSON output into validate (NOT both reading same stdin)
	run docker run --rm -i caddy:2-alpine sh -c '
		caddy adapt --config /dev/stdin | caddy validate --config /dev/stdin
	' <<<"$rendered"
	[ "$status" -eq 0 ]
}

@test "Caddyfile with custom-cert tls directive (mode 4) validates" {
	if [[ -z "${RUN_INTEGRATION:-}" ]]; then
		skip "set RUN_INTEGRATION=1 to enable container validation"
	fi

	# Generate a fake cert pair and feed it via stdin (avoids volume mounts +
	# trap handlers, which can interfere with bats' subshell isolation).
	local tmpdir
	tmpdir="$(mktemp -d)" || skip "mktemp failed"
	openssl req -x509 -newkey rsa:2048 -nodes \
		-keyout "$tmpdir/key.pem" \
		-out "$tmpdir/cert.pem" \
		-days 1 -subj "/CN=test" 2>/dev/null || skip "openssl failed"

	# Build a Caddyfile variant for mode 4:
	#   - comment out `auto_health off` (so Caddy can load the cert)
	#   - uncomment the 4 `tls` lines (one per site)
	# NOTE: bash's ${var//pattern/replacement} treats `#` as a longest-match
	# anchor, so we use sed for the `tls` uncomment step.
	local rendered
	rendered="$(caddy_render)"
	rendered="$(echo "$rendered" | sed 's|^	auto_health off|#	auto_health off|')"
	rendered="$(echo "$rendered" | sed 's|^	# tls /certs/cert.pem /certs/key.pem|	tls /certs/cert.pem /certs/key.pem|')"

	# Inline the cert + key as env vars and use a Caddyfile variant that
	# references /dev/stdin for the cert files. Simpler: mount and pipe.
	# NOTE: -i is required to keep stdin open so caddy adapt can read from it.
	run docker run --rm -i \
		-v "$tmpdir/cert.pem:/certs/cert.pem:ro" \
		-v "$tmpdir/key.pem:/certs/key.pem:ro" \
		caddy:2-alpine sh -c 'caddy adapt --config /dev/stdin | caddy validate --config /dev/stdin' \
		<<<"$rendered"

	# Clean up tmpdir manually (no trap — keeps bats happy)
	rm -rf "$tmpdir" 2>/dev/null || true

	[ "$status" -eq 0 ]
}
