# Tanka Dev Infra

Private LAN-only development infrastructure for company-computer use.

This project provisions:

- GitLab CE for private Git repositories and GitLab Package Registry
- Caddy as an internal HTTP/HTTPS reverse proxy
- Bit Cloud as the npm/package registry target
- A self-hosted Bit scope server for internal component hosting

## Network Model

Public internet exposure is out of scope.

Use the local hostnames:

```text
http://gitlab.internal.local -> GitLab
https://gitlab.internal.local -> GitLab
http://bit.internal.local -> Bit scope server
https://bit.internal.local -> Bit scope server
http://npm.internal.local -> Bit Cloud registry proxy
https://npm.internal.local -> Bit Cloud registry proxy
```

Or use the HTTPS hostnames directly:

```text
https://gitlab.internal.local -> GitLab
https://bit.internal.local -> Bit scope server
https://npm.internal.local -> Bit Cloud registry proxy
```

## Quick Start

```bash
cp .env.example .env
mkdir -p data backups
docker compose up -d
```

Then open:

```text
http://gitlab.internal.local
https://gitlab.internal.local
http://bit.internal.local
https://bit.internal.local
```

## Trust the Internal CA

Services use Caddy's internal CA. To get a green lock without browser warnings,
install the bundled root certificate (`caddy/root-ca.crt`, public cert only — no private key) once per device.

macOS:

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain caddy/root-ca.crt
```

Or double-click `caddy/root-ca.crt`, open it in Keychain Access, and set it to "Always Trust".

Then fully restart the browser (Cmd+Q).

Note: if you ever run `docker compose down -v`, Caddy regenerates the CA. Re-export it with:

```bash
cp data/caddy/data/caddy/pki/authorities/local/root.crt caddy/root-ca.crt
```

## HTTPS Later

If you later expose these services beyond the LAN, keep HTTPS in front of the public entry point. Caddy can manage local/internal certificates automatically for the current setup.

## GitLab Defaults

The Compose config sets:

- public signup disabled
- project visibility default private
- usage ping disabled
- built-in package registry enabled
- Git SSH exposed on the LAN IP only

Change the root password immediately after first login.

## Bit Usage

Target package distribution:

1. Use GitLab for source control.
2. Use local Bit CLI for `bit build`, `bit start`, and `bit tag`.
3. Publish Bit components and generated npm packages through the Bit Cloud registry proxy.
4. Use the local Bit scope server on `https://bit.internal.local`.

## Docs

- [Project plan](docs/project-plan.md)
- [DNS](docs/dns.md)
- [TLS](docs/ssl.md)
- [Operations](docs/operations.md)
- [Security checklist](docs/security-checklist.md)
