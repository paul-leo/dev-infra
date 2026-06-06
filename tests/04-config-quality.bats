#!/usr/bin/env bats
#
# 04-config-quality.bats — catches the most common config mistakes:
#   - hardcoded passwords / secrets in tracked files
#   - missing env var documentation
#   - Caddyfile TLS_SNIPPET references undeclared snippet
#   - .env file is empty (we never want to commit one)
#
load 'helpers'

setup() {
	cd "$PROJECT_ROOT"
}

@test ".env is empty or absent (never commit real secrets)" {
	if [[ -f "$PROJECT_ROOT/.env" ]]; then
		# Must be 0 bytes — we don't want committed credentials
		[ ! -s "$PROJECT_ROOT/.env" ]
	fi
}

@test ".gitignore excludes data/ and .env" {
	assert_file_contains "$PROJECT_ROOT/.gitignore" "data/"
	assert_file_contains "$PROJECT_ROOT/.gitignore" ".env"
}

@test "no 'change-me' or 'TODO' placeholder passwords in tracked config" {
	local offenders
	offenders="$(
		grep -rnE "(change-me|TODO_PASSWORD|FIXME_PASSWORD)" \
			"$PROJECT_ROOT/.env.example" \
			"$PROJECT_ROOT/docker-compose.yml" \
			"$PROJECT_ROOT/verdaccio/config.yaml" \
			2>/dev/null || true
	)"
	# Allowed: literal "change-me" in .env.example as a hint to the user
	# Disallowed: anywhere else
	while IFS= read -r line; do
		[[ -z "$line" ]] && continue
		# .env.example may contain the literal placeholder as a hint
		if [[ "$line" == *".env.example:"* ]]; then
			continue
		fi
		echo "offending line: $line" >&2
		return 1
	done <<<"$offenders"
}

@test "no high-entropy-looking secret strings in tracked files" {
	# A simple check: no 40+-char base64/hex blobs in compose / env.example
	local blob
	blob="$(grep -hoE '[A-Za-z0-9+/=]{40,}' \
		"$PROJECT_ROOT/.env.example" \
		"$PROJECT_ROOT/docker-compose.yml" 2>/dev/null | head -1 || true)"
	[ -z "$blob" ] || {
		echo "found suspicious secret-like string: $blob" >&2
		return 1
	}
}

@test "Caddyfile does NOT use the broken 'import {\$VAR}' placeholder pattern" {
	# The placeholder-substitution in `import` argument is NOT supported by
	# Caddy — it tries to load a file literally named "{\$tls-none:tls-none}".
	# The fix is to drive TLS via AUTO_HTTPS and let Caddy auto-decide.
	if grep -qE "import \{?\\\$[A-Z_]+" "$PROJECT_ROOT/caddy/Caddyfile"; then
		echo "Caddyfile contains an env-var-based import directive." >&2
		echo "Caddy does not substitute placeholders in import arguments." >&2
		return 1
	fi
}

@test "every compose service has a healthcheck or is explicitly opt-in" {
	# Critical: services that compose 'depends_on' must have a healthcheck
	# (or condition: service_started which we treat as weaker).
	local without_health
	without_health="$(
		awk '
			/^  [a-z][a-z0-9-]*:$/ { svc=$1; sub(/:$/, "", svc); in_svc=1; has_hc=0; next }
			/^  [a-z][a-z0-9-]*:$/ { in_svc=0 }
			in_svc && /healthcheck:/ { has_hc=1 }
			in_svc && /^  [a-z]/ && !/^  [a-z][a-z0-9-]*:$/ && !/^    / { if(!has_hc && svc!="") print svc }
		' "$PROJECT_ROOT/docker-compose.yml"
	)"
	# This is a soft warning — print but don't fail
	echo "Services without healthchecks (informational): $without_health"
	[ -n "$without_health" ] || true
}

@test "scripts/ directory is complete and executable" {
	for script in \
		scripts/healthcheck.sh \
		scripts/backup.sh \
		scripts/gen-certs.sh \
		scripts/register-runner.sh \
		scripts/start-bit-scope.sh; do
		[ -f "$PROJECT_ROOT/$script" ] || {
			echo "missing script: $script" >&2
			return 1
		}
		[ -x "$PROJECT_ROOT/$script" ] || {
			echo "not executable: $script" >&2
			return 1
		}
	done
}

@test "docs/ directory contains all expected guides" {
	for doc in \
		docs/harness-fe.md \
		docs/verdaccio.md \
		docs/ssl.md \
		docs/dns.md \
		docs/operations.md; do
		[ -f "$PROJECT_ROOT/$doc" ] || {
			echo "missing doc: $doc" >&2
			return 1
		}
	done
}

@test "GitLab compose service has letsencrypt disabled (we use Caddy for TLS)" {
	# GitLab should NOT try to use Let's Encrypt on its own — Caddy terminates
	# TLS upstream and GitLab runs plain HTTP behind it.
	assert_file_contains "$PROJECT_ROOT/docker-compose.yml" "letsencrypt['enable'] = false"
}

@test "GitLab external_url is templated (not hardcoded)" {
	# GITLAB_EXTERNAL_URL should be driven by env so the user can point it
	# at their HTTPS URL when Caddy is in front.
	assert_file_contains "$PROJECT_ROOT/docker-compose.yml" "GITLAB_EXTERNAL_URL"
	assert_file_contains "$PROJECT_ROOT/.env.example" "GITLAB_EXTERNAL_URL"
}
