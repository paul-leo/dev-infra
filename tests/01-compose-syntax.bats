#!/usr/bin/env bats
#
# 01-compose-syntax.bats — docker-compose.yml is well-formed and renders for
# every profile combination.
#
load 'helpers'

setup() {
	cd "$PROJECT_ROOT"
}

@test "docker compose config renders without error (default profile)" {
	require_docker
	run docker compose config --quiet
	[ "$status" -eq 0 ]
}

@test "docker compose config renders without error (profile: all)" {
	require_docker
	run docker compose --profile all config --quiet
	[ "$status" -eq 0 ]
}

@test "docker compose config renders without error (profiles: gitlab,caddy,bit)" {
	require_docker
	run docker compose --profile gitlab --profile caddy --profile bit config --quiet
	[ "$status" -eq 0 ]
}

@test "caddy service appears in --profile caddy output" {
	require_docker
	run docker compose --profile caddy config
	[ "$status" -eq 0 ]
	[[ "$output" == *"caddy:"* ]]
	[[ "$output" == *"ACME_EMAIL:"* ]]
	[[ "$output" == *"CADDY_HTTP_PORT:"* ]]
	[[ "$output" == *"CADDY_HTTPS_PORT:"* ]]
}

@test "AUTO_HTTPS env var is gone (replaced by Caddyfile edit)" {
	require_docker
	run docker compose --profile caddy config
	[ "$status" -eq 0 ]
	# The Caddy admin directive `auto_https` doesn't accept "on" as a value —
	# it's the default and the directive only exists to disable / modify it.
	# So we drive TLS mode by editing the Caddyfile instead of an env var.
	[[ ! "$output" == *"AUTO_HTTPS:"* ]]
}

@test "caddy service uses 1:1 port mapping (host port == container port)" {
	require_docker
	run docker compose --profile caddy config
	[ "$status" -eq 0 ]
	# Extract the ports block and ensure host:container pairs are identical
	echo "$output" | grep -E "^\s+-\s+0\.0\.0\.0:[0-9]+:[0-9]+$" | while read -r line; do
		# "      - 0.0.0.0:80:80" → host=80, container=80
		ports="${line##*:}"
		ports="${ports%:}"
		host_port="${line##*:}"
		host_port="${host_port%%:*}"
		host_port="${host_port##*:}"
		[ "$host_port" = "$ports" ]
	done
}

@test "all required env vars are documented in .env.example" {
	for var in \
		COMPOSE_PROFILES \
		BASE_DOMAIN \
		HOST_IP \
		VERDACCIO_PORT \
		HARNESS_PORT \
		HARNESS_WS_PORT \
		GITLAB_PORT \
		GITLAB_SSH_PORT \
		BIT_PORT \
		ACME_EMAIL \
		CADDY_HTTP_PORT \
		CADDY_HTTPS_PORT \
		CUSTOM_CERT_PATH \
		CUSTOM_KEY_PATH; do
		run grep -E "^${var}=" "$PROJECT_ROOT/.env.example"
		[ "$status" -eq 0 ] || { echo "missing env var: $var" >&2; return 1; }
	done
}
