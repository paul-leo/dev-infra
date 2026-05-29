# Tanka Dev Infra

Private LAN-only development infrastructure for company-computer use.

This project provisions:

- GitLab CE for private Git repositories and GitLab Package Registry
- Caddy as an internal HTTPS reverse proxy
- Verdaccio as an optional private npm registry
- A placeholder route for Bit service POC

## Network Model

Public internet exposure is out of scope.

Use internal DNS only:

```text
gitlab.internal.local -> company computer LAN IP
npm.internal.local    -> company computer LAN IP
bit.internal.local    -> company computer LAN IP
```

## Quick Start

```bash
cp .env.example .env
mkdir -p caddy/certs data backups
docker compose up -d
```

Then open:

```text
https://gitlab.internal.local
https://npm.internal.local
https://bit.internal.local
```

## TLS

Because `.dev` requires HTTPS, provide either:

- an internal CA certificate, or
- a DNS-01 issued wildcard certificate

Expected files for the default Caddyfile:

```text
caddy/certs/internal.local.crt
caddy/certs/internal.local.key
```

## GitLab Defaults

The Compose config sets:

- public signup disabled
- project visibility default private
- usage ping disabled
- built-in package registry enabled
- Git SSH exposed on the LAN IP only

Change the root password immediately after first login.

## Bit Usage

Recommended first phase:

1. Use GitLab for source control.
2. Use local Bit CLI for `bit build`, `bit start`, and `bit tag`.
3. Publish npm packages to GitLab Package Registry or Verdaccio.
4. POC Bit self-hosted service only after the Git/npm flow is stable.

## Docs

- [Project plan](docs/project-plan.md)
- [DNS](docs/dns.md)
- [TLS](docs/ssl.md)
- [Operations](docs/operations.md)
- [Security checklist](docs/security-checklist.md)
