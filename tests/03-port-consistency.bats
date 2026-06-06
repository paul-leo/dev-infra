#!/usr/bin/env bats
#
# 03-port-consistency.bats — host port, container port, and Caddy listen
# port are all driven by the same env var (1:1:1). Catches drift between
# docker-compose.yml and the Caddyfile.
#
load 'helpers'

setup() {
	cd "$PROJECT_ROOT"
}

@test "CADDY_HTTP_PORT drives host, container, and Caddyfile http_port" {
	# Caddyfile must reference {$CADDY_HTTP_PORT:80} in the global block
	assert_file_contains "$PROJECT_ROOT/caddy/Caddyfile" "http_port  {\$CADDY_HTTP_PORT"
	# compose must use \${CADDY_HTTP_PORT} in the host mapping
	assert_file_contains "$PROJECT_ROOT/docker-compose.yml" "CADDY_HTTP_PORT"
}

@test "CADDY_HTTPS_PORT drives host, container, and Caddyfile https_port" {
	assert_file_contains "$PROJECT_ROOT/caddy/Caddyfile" "https_port {\$CADDY_HTTPS_PORT"
	assert_file_contains "$PROJECT_ROOT/docker-compose.yml" "CADDY_HTTPS_PORT"
}

@test "Caddyfile reverse_proxy targets match service container ports" {
	local rendered
	rendered="$(caddy_render tls-none)"

	# gitlab:80
	[[ "$rendered" == *"reverse_proxy gitlab:80"* ]]
	# verdaccio:4873
	[[ "$rendered" == *"reverse_proxy verdaccio:4873"* ]]
	# bit:3000
	[[ "$rendered" == *"reverse_proxy bit:3000"* ]]
	# harness:9050 (HTTP) + 9051 (WS)
	[[ "$rendered" == *"reverse_proxy harness:9050"* ]]
	[[ "$rendered" == *"reverse_proxy @websocket harness:9051"* ]]
}

@test "no host:container port pair in caddy service is asymmetric" {
	require_docker
	run docker compose --profile caddy config
	[ "$status" -eq 0 ]

	# Extract caddy service ports block
	local caddy_block ports_line host_port container_port
	caddy_block="$(echo "$output" | sed -n '/^  caddy:/,/^  [a-z]/p' | sed '/^  [a-z]/d')"

	# For each ports entry, host == container
	while IFS= read -r line; do
		[[ "$line" =~ 0\.0\.0\.0:([0-9]+):([0-9]+) ]] || continue
		host_port="${BASH_REMATCH[1]}"
		container_port="${BASH_REMATCH[2]}"
		[ "$host_port" = "$container_port" ] || {
			echo "asymmetric port mapping: host=$host_port container=$container_port" >&2
			return 1
		}
	done <<<"$caddy_block"
}

@test "all service host ports are unique" {
	require_docker
	run docker compose --profile all config
	[ "$status" -eq 0 ]

	# Pull every host port (the second number in host:container pairs)
	local ports
	ports="$(echo "$output" | grep -oE '127\.0\.0\.1:[0-9]+:[0-9]+' | cut -d: -f2 | sort)"
	local dupes
	dupes="$(echo "$ports" | uniq -d)"
	[ -z "$dupes" ] || {
		echo "duplicate host ports: $dupes" >&2
		return 1
	}
}
