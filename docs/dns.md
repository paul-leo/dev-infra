# DNS Configuration

## When Do You Need DNS?

- **Direct port access** (default): No DNS needed. Access via `http://<ip>:9080`.
- **Caddy with domains**: Requires DNS or `/etc/hosts` to resolve `<service>.BASE_DOMAIN`.

## Domain Scheme

With `BASE_DOMAIN=dev.example.com`, services are routed as:

```
gitlab.dev.example.com   → GitLab
npm.dev.example.com      → Verdaccio
bit.dev.example.com      → Bit
harness.dev.example.com  → Harness-FE
```

## Setup Options

### /etc/hosts (Single Machine / Quick Test)

```text
127.0.0.1  gitlab.dev.local npm.dev.local bit.dev.local harness.dev.local
```

Or for a LAN server at `192.168.1.100`:

```text
192.168.1.100  gitlab.dev.local npm.dev.local bit.dev.local harness.dev.local
```

### Wildcard DNS (Recommended for Teams)

Point `*.dev.example.com` to your server IP using a DNS wildcard record:

```
*.dev.example.com  →  A  →  192.168.1.100
```

This way any `<service>.dev.example.com` resolves automatically.

### Router DNS / Pi-hole / AdGuard Home

Add local DNS overrides for your LAN:

```
gitlab.dev.local   →  192.168.1.100
npm.dev.local      →  192.168.1.100
bit.dev.local      →  192.168.1.100
harness.dev.local  →  192.168.1.100
```

### dnsmasq (Linux Lightweight DNS)

```bash
# /etc/dnsmasq.conf
address=/dev.local/192.168.1.100
```

All `*.dev.local` will resolve to your server.

## Verifying DNS

```bash
# Check resolution
nslookup gitlab.dev.local
dig gitlab.dev.local

# Test HTTP
curl -I http://gitlab.dev.local
curl -I https://gitlab.dev.local  # if Caddy is running
```

## Custom Per-Service Domains

If you don't want the `<service>.BASE_DOMAIN` pattern, override individually in `.env`:

```env
GITLAB_DOMAIN=code.company.com
NPM_DOMAIN=registry.company.com
BIT_DOMAIN=components.company.com
HARNESS_DOMAIN=agent.company.com
```

Each domain needs its own DNS record pointing to the server.

## Caddy + Public Domain (Let's Encrypt)

For automatic Let's Encrypt certificates on a public domain:

1. Point DNS to your server (A record or wildcard)
2. Ensure ports 80/443 are reachable from the internet
3. Set in `.env`:

```env
BASE_DOMAIN=dev.yourcompany.com
ACME_EMAIL=admin@yourcompany.com
COMPOSE_PROFILES=caddy
AUTO_HTTPS=true
TLS_SNIPPET=tls-none
```

Caddy handles certificate provisioning and renewal automatically.

For the other TLS modes (plain HTTP, internal self-signed CA, custom
certificate) and a full env-var reference, see [docs/ssl.md](ssl.md).
