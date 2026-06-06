# ─── Shared helpers for bats tests ──────────────────────────────────────────
# Sourced from each .bats file via: load 'helpers'
#
# Provides:
#   PROJECT_ROOT   absolute path to the project root
#   COMMON_ENV     list of env vars every Caddy-render test must set
#   cad_render     function: render Caddyfile for a given TLS_SNIPPET mode
#   cad_validate   function: validate a rendered Caddyfile in a caddy:2-alpine container
#   require_docker skip helper

PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME:-tests/run-all.sh}")/.." && pwd)"

# Minimum env vars that must be set for the Caddyfile to render.
COMMON_ENV=(
	"AUTO_HTTPS=false"
	"CADDY_HTTP_PORT=80"
	"CADDY_HTTPS_PORT=443"
	"ACME_EMAIL="
	"GITLAB_DOMAIN=gitlab.test"
	"BIT_DOMAIN=bit.test"
	"NPM_DOMAIN=npm.test"
	"HARNESS_DOMAIN=harness.test"
)

# ─── require_docker: skip the test if docker is missing ─────────────────────
require_docker() {
	if [[ "${SKIP_DOCKER:-0}" == "1" ]] || ! command -v docker >/dev/null 2>&1; then
		skip "docker not available"
	fi
}

# ─── caddy_render <auto_https> [acme_email] ──────────────────────────────────
# Echoes a fully-substituted Caddyfile to stdout.
# Args:
#   $1 — value for AUTO_HTTPS (on | off). Default: off
#   $2 — value for ACME_EMAIL. Default: empty
#
# Caddy uses {$VAR:default} placeholder syntax which envsubst doesn't
# recognise. We use sed with explicit per-variable substitutions.
# Special case: when ACME_EMAIL is empty, the `email` directive is
# commented out (Caddy requires a value).
caddy_render() {
	local auto_https="${1:-off}"
	local acme_email="${2:-}"
	local file="$PROJECT_ROOT/caddy/Caddyfile"
	if [[ ! -f "$file" ]]; then
		echo "Caddyfile not found: $file" >&2
		return 1
	fi

	local rendered
	rendered="$(sed -E \
		-e "s|\\{\\\$AUTO_HTTPS:[^}]*\\}|${auto_https}|g" \
		-e 's|\{\$CADDY_HTTP_PORT:[^}]*\}|80|g' \
		-e 's|\{\$CADDY_HTTPS_PORT:[^}]*\}|443|g' \
		-e 's|\{\$GITLAB_DOMAIN:[^}]*\}|gitlab.test|g' \
		-e 's|\{\$BIT_DOMAIN:[^}]*\}|bit.test|g' \
		-e 's|\{\$NPM_DOMAIN:[^}]*\}|npm.test|g' \
		-e 's|\{\$HARNESS_DOMAIN:[^}]*\}|harness.test|g' \
		"$file")"

	# ACME_EMAIL: when empty, use `none` (matches the Caddyfile's default
	# and produces the valid directive `email none`). Otherwise substitute
	# the user-provided value.
	local effective_email="${acme_email:-none}"
	echo "$rendered" | sed -E "s|\\{\\\$ACME_EMAIL:[^}]*\\}|${effective_email}|g"
}

# ─── caddy_validate <auto_https> ─────────────────────────────────────────────
# Validates a Caddyfile in a caddy:2-alpine container. Returns 0 on success.
# Auto-skips when docker is unavailable.
caddy_validate() {
	local auto_https="${1:-off}"
	require_docker

	local rendered
	rendered="$(caddy_render "$auto_https")"

	# Pipe the rendered Caddyfile to `caddy adapt`, then `caddy validate`
	# the resulting JSON config. Note: `caddy adapt` writes JSON to stdout
	# which `caddy validate` reads as its config.
	docker run --rm -i caddy:2-alpine sh -c '
		caddy adapt --config /dev/stdin | caddy validate --config /dev/stdin
	' <<<"$rendered"
}

# ─── assert_file_contains <file> <needle> ──────────────────────────────────
assert_file_contains() {
	local file="$1" needle="$2"
	if ! grep -qF -- "$needle" "$file"; then
		{
			echo "Expected to find:"
			echo "  $needle"
			echo "in $file, but it was missing."
			echo "----- file contents -----"
			cat "$file"
			echo "-------------------------"
		} >&2
		return 1
	fi
}

# ─── assert_file_not_contains <file> <needle> ──────────────────────────────
assert_file_not_contains() {
	local file="$1" needle="$2"
	if grep -qF -- "$needle" "$file"; then
		{
			echo "Did NOT expect to find:"
			echo "  $needle"
			echo "in $file, but it was present."
		} >&2
		return 1
	fi
}
