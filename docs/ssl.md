# Caddy Reverse Proxy & TLS Modes

The Caddy reverse proxy is **optional** — enable it with the `caddy` profile to get
single-port domain-based routing for all services.

```bash
docker compose --profile caddy up -d
```

You pick the **TLS / HTTP mode** that fits your deployment. Four are supported,
and switching between them is a one-env-var change in `.env`.

---

## Mode Comparison

| # | Mode | Use case | `AUTO_HTTPS` | `TLS_SNIPPET` |
|---|------|----------|:------------:|:------------:|
| 1 | **Plain HTTP** | Dev boxes, internal-only networks behind a TLS terminator | `false` | `tls-none` |
| 2 | **Public + Let's Encrypt** | Public deployment with real DNS and reachable 80/443 | `true` | `tls-none` |
| 3 | **Internal CA (self-signed)** | LAN / air-gapped with `.local` or `.internal` domains | `true` | `tls-internal` |
| 4 | **Custom certificate** | Corporate CA, purchased cert, or your own self-signed pair | `true` or `false` | `tls-custom` |

> **Ports are unified.** `CADDY_HTTP_PORT` and `CADDY_HTTPS_PORT` drive the host
> port mapping, the container port, **and** Caddy's `http_port` / `https_port`
> directives simultaneously. Change one number, everything else follows.

---

## Mode 1 — Plain HTTP

Default out of the box. No TLS, no ACME, no cert files.

```env
AUTO_HTTPS=false
TLS_SNIPPET=tls-none
```

Access:
```
http://gitlab.localhost
http://npm.localhost
http://harness.localhost
http://bit.localhost
```

Use this when:
- You're running on a developer laptop
- You have a TLS-terminating load balancer or reverse proxy in front
- You're in a trusted network and HTTPS isn't required

---

## Mode 2 — Public Domain (Let's Encrypt)

Free, automatic, trusted certificates from Let's Encrypt.

### Requirements

- DNS A records for each subdomain point to your server
- Ports `80` and `443` reachable from the public internet
- A reachable email for ACME registration (Let's Encrypt notifications)

### Configuration

```env
BASE_DOMAIN=your-domain.com
ACME_EMAIL=admin@your-domain.com

AUTO_HTTPS=true
TLS_SNIPPET=tls-none
```

Caddy auto-issues and auto-renews certificates. No file management, no
cron, no `gen-certs.sh`. The first start takes ~30s while the ACME
challenge runs.

> If you also need direct HTTPS access (e.g. `https://gitlab.your-domain.com`
> via a non-Caddy route), point `GITLAB_EXTERNAL_URL` to the HTTPS URL:
> ```env
> GITLAB_EXTERNAL_URL=https://gitlab.your-domain.com
> ```

---

## Mode 3 — Internal Self-Signed CA

Caddy issues its own certificates from a built-in CA. Works for
`.local`, `.internal`, and any domain that doesn't resolve on the
public internet.

### Configuration

```env
BASE_DOMAIN=dev.local
AUTO_HTTPS=true
TLS_SNIPPET=tls-internal
```

### Trust the Caddy Root CA on client machines

Extract the CA, then add it to each client's trust store.

```bash
# 1. Copy the CA out of the container
docker compose cp caddy:/data/caddy/pki/authorities/local/root.crt ./caddy-root.crt
```

**macOS**
```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain ./caddy-root.crt
```

**Linux (Debian / Ubuntu)**
```bash
sudo cp ./caddy-root.crt /usr/local/share/ca-certificates/caddy.crt
sudo update-ca-certificates
```

**Linux (RHEL / Fedora)**
```bash
sudo cp ./caddy-root.crt /etc/pki/ca-trust/source/anchors/caddy.crt
sudo update-ca-trust
```

**Windows (PowerShell as Administrator)**
```powershell
Import-Certificate -FilePath .\caddy-root.crt `
  -CertStoreLocation Cert:\LocalMachine\Root
```

### Add DNS entries (LAN)

Either real DNS, or per-machine `/etc/hosts` (Windows: `C:\Windows\System32\drivers\etc\hosts`):

```
192.168.1.100  gitlab.dev.local npm.dev.local bit.dev.local harness.dev.local
```

---

## Mode 4 — Custom Certificate

Bring your own — corporate CA, purchased cert, or a self-signed pair
from `gen-certs.sh`.

### Option A — Use the bundled generator

Generates a self-signed Root CA + leaf certificate. Useful for testing,
staging, or air-gapped production.

```bash
./scripts/gen-certs.sh your-domain.com
# Writes: certs/ca.crt, certs/ca.key, certs/cert.pem, certs/key.pem
```

Then in `.env`:
```env
AUTO_HTTPS=false
TLS_SNIPPET=tls-custom
CUSTOM_CERT_PATH=./certs/cert.pem
CUSTOM_KEY_PATH=./certs/key.pem
```

Distribute `certs/ca.crt` to clients and trust it using the OS-specific
commands in **Mode 3** above.

### Option B — Bring your own files

Drop your cert chain and key into `./certs/`:

```
certs/
├── cert.pem    # certificate or fullchain (PEM)
└── key.pem     # private key (PEM, unencrypted)
```

Set the paths in `.env`:
```env
AUTO_HTTPS=false
TLS_SNIPPET=tls-custom
CUSTOM_CERT_PATH=./certs/cert.pem
CUSTOM_KEY_PATH=./certs/key.pem
```

> Caddy supports per-site certificate customization by editing
> `caddy/Caddyfile` and swapping `tls /certs/cert.pem /certs/key.pem`
> for explicit paths per site.

---

## Port Reference

| Env var | Default | Used for |
|---------|:-------:|----------|
| `CADDY_HTTP_PORT` | `80` | Caddy's HTTP listen port + docker host:container mapping |
| `CADDY_HTTPS_PORT` | `443` | Caddy's HTTPS listen port + docker host:container mapping |
| `HOST_IP` | `127.0.0.1` | Bind address (use `0.0.0.0` to expose on all interfaces) |

Change `CADDY_HTTP_PORT` to move Caddy off the default port — for
example, set it to `8080` to run alongside another web server on `:80`:

```env
CADDY_HTTP_PORT=8080
```

Both the host mapping (`8080:8080`) and Caddy's `http_port` directive
update from this single variable.

---

## Domain Reference

| Env var | Default | Overrides |
|---------|---------|-----------|
| `BASE_DOMAIN` | `localhost` | Base for all per-service domains |
| `GITLAB_DOMAIN` | `gitlab.${BASE_DOMAIN}` | GitLab vhost |
| `BIT_DOMAIN` | `bit.${BASE_DOMAIN}` | Bit scope vhost |
| `NPM_DOMAIN` | `npm.${BASE_DOMAIN}` | Verdaccio vhost |
| `HARNESS_DOMAIN` | `harness.${BASE_DOMAIN}` | Harness-FE vhost |

Override individually for asymmetric setups, e.g.:

```env
BASE_DOMAIN=example.com
GITLAB_DOMAIN=code.example.com       # custom subdomain
NPM_DOMAIN=registry.example.com      # custom subdomain
# BIT_DOMAIN and HARNESS_DOMAIN fall back to bit.example.com / harness.example.com
```

---

## Verifying TLS

```bash
# Show the active certificate
openssl s_client -connect gitlab.your-domain.com:443 \
  -servername gitlab.your-domain.com </dev/null 2>/dev/null \
  | openssl x509 -text -noout

# Verbose curl (look for "subject=" and "issuer=" lines)
curl -v https://gitlab.your-domain.com

# Self-signed? Skip verify for one-off testing
curl -k https://gitlab.dev.local
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Caddy logs "acme: error" | DNS not pointing to server, or 80 blocked | Verify `dig gitlab.your-domain.com`, open port 80 |
| Browser shows "Not Secure" in mode 1 | Expected — HTTP only | Switch to mode 2/3/4 if you need HTTPS |
| TLS error after switching modes | Stale certs in Caddy data dir | `docker compose down && rm -rf data/caddy && docker compose up -d caddy` |
| Cert file not found in mode 4 | `certs/cert.pem` missing | Run `./scripts/gen-certs.sh` or copy your own |
| Port 80 already in use | Another web server | Set `CADDY_HTTP_PORT=8080` (or whichever free port) |
