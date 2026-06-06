# dev-infra

One-command self-hosted development infrastructure. Docker Compose gives you a private Git server, npm registry, component platform, and AI agent gateway — ready in minutes.

## What's Included

| Service | Description | Default Port |
|---------|-------------|:------------:|
| **Verdaccio** | Private npm registry with web UI | 9040 |
| **Harness-FE** | AI agent MCP gateway ([harness-fe](https://github.com/Morphicai/harness-fe)) | 9050 / 9051 |
| **GitLab CE** | Git hosting + CI/CD + package registry | 9080 |
| **GitLab Runner** | CI/CD pipeline executor | — |
| **Bit Server** | Component sharing platform | 9030 |
| **Caddy** | Reverse proxy with auto HTTPS | 80 / 443 |

All ports start from `90xx` to avoid conflicts with common dev ports.

## Quick Start

```bash
git clone https://github.com/user/dev-infra.git && cd dev-infra
cp .env.example .env
# Edit .env — set GITLAB_ROOT_PASSWORD at minimum
docker compose up -d
```

That's it. Verdaccio and Harness-FE start immediately. GitLab takes 3–5 minutes on first boot.

## Selective Services (Profiles)

Only start what you need:

```bash
# Core only (verdaccio + harness) — lightweight, fast
docker compose up -d

# Add GitLab
docker compose --profile gitlab up -d

# Add Caddy for HTTPS + domain routing
docker compose --profile caddy up -d

# Everything
docker compose --profile all up -d
```

Or set once in `.env`:

```env
COMPOSE_PROFILES=gitlab,caddy
```

| Profile | Services |
|---------|----------|
| *(core)* | verdaccio, harness |
| `gitlab` | gitlab, gitlab-runner |
| `bit` | bit scope server |
| `caddy` | caddy reverse proxy |
| `all` | everything above |

## Domain Configuration

There are two ways to expose services: **direct ports** (no Caddy) or
**Caddy vhost routing** (single entry point, optional TLS).

### Option A — Direct Port Access (default, no Caddy)

No DNS needed. Each service listens on its own host port:

```
http://localhost:9080   → GitLab
http://localhost:9040   → Verdaccio
http://localhost:9050   → Harness-FE
http://localhost:9030   → Bit
```

### Option B — Caddy Reverse Proxy (single hostname, optional HTTPS)

Enable the `caddy` profile, set your base domain, and pick a TLS mode:

```env
COMPOSE_PROFILES=gitlab,caddy
BASE_DOMAIN=your-domain.com
```

All four services become available under one hostname:

```
http(s)://gitlab.your-domain.com
http(s)://npm.your-domain.com
http(s)://bit.your-domain.com
http(s)://harness.your-domain.com
```

#### Pick a TLS mode

The Caddy proxy supports four modes — pick the one that matches your
deployment. Flip two env vars in `.env`:

| Mode | When to use | `AUTO_HTTPS` | `TLS_SNIPPET` |
|------|-------------|:------------:|:-------------:|
| 1. Plain HTTP | Dev box, behind another TLS terminator, trusted LAN | `false` | `tls-none` |
| 2. Let's Encrypt | Public deployment, real DNS, reachable 80/443 | `true` | `tls-none` |
| 3. Self-signed CA | LAN / air-gapped with `.local` or `.internal` | `true` | `tls-internal` |
| 4. Custom certificate | Corporate CA, purchased cert, or your own self-signed pair | `true` or `false` | `tls-custom` |

**Mode 2 example — Let's Encrypt:**
```env
AUTO_HTTPS=true
TLS_SNIPPET=tls-none
ACME_EMAIL=admin@your-domain.com
```

**Mode 3 example — internal CA for `dev.local`:**
```env
AUTO_HTTPS=true
TLS_SNIPPET=tls-internal
```
Then trust Caddy's CA on each client:
```bash
docker compose cp caddy:/data/caddy/pki/authorities/local/root.crt ./caddy-root.crt
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ./caddy-root.crt   # macOS
```

**Mode 4 example — your own cert:**
```bash
./scripts/gen-certs.sh your-domain.com     # or copy your own files into ./certs/
```
```env
AUTO_HTTPS=false
TLS_SNIPPET=tls-custom
```

See [docs/ssl.md](docs/ssl.md) for the full per-mode walkthrough, port
reference, and troubleshooting.

### Custom Per-Service Domains

Override individual service domains in `.env`:

```env
GITLAB_DOMAIN=code.your-domain.com
NPM_DOMAIN=registry.your-domain.com
HARNESS_DOMAIN=agent.your-domain.com
# BIT_DOMAIN falls back to bit.your-domain.com
```

### Custom Caddy Ports

The same env var drives the host mapping, container port, **and**
Caddy's listen port. Change one number to move everything:

```env
CADDY_HTTP_PORT=8080     # host 8080 → container 8080 → Caddy listens on 8080
```

## Configuration Reference

All settings live in `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `COMPOSE_PROFILES` | `all` | Which optional services to start |
| `HOST_IP` | `127.0.0.1` | Bind address for direct port access |
| `BASE_DOMAIN` | `localhost` | Base domain (Caddy routes `<service>.BASE_DOMAIN`) |
| `GITLAB_PORT` | `9080` | GitLab web |
| `GITLAB_SSH_PORT` | `9022` | GitLab SSH |
| `GITLAB_ROOT_PASSWORD` | — | Initial root password (required) |
| `GITLAB_EXTERNAL_URL` | `http://localhost:9080` | How users reach GitLab |
| `BIT_PORT` | `9030` | Bit scope server |
| `VERDACCIO_PORT` | `9040` | npm registry |
| `HARNESS_PORT` | `9050` | Harness-FE HTTP/MCP |
| `HARNESS_WS_PORT` | `9051` | Harness-FE WebSocket |
| `HARNESS_MODE` | `solo` | `solo` or `governed` (team RBAC) |
| `CADDY_HTTP_PORT` | `80` | Caddy HTTP port (host + container + Caddy listen) |
| `CADDY_HTTPS_PORT` | `443` | Caddy HTTPS port (host + container + Caddy listen) |
| `AUTO_HTTPS` | `false` | Caddy auto-HTTPS behaviour (`on`/`off`) |
| `TLS_SNIPPET` | `tls-none` | TLS mode: `tls-none` / `tls-internal` / `tls-custom` |
| `ACME_EMAIL` | — | Email for Let's Encrypt (mode 2) |
| `CUSTOM_CERT_PATH` | `./certs/cert.pem` | Custom cert path (mode 4) |
| `CUSTOM_KEY_PATH` | `./certs/key.pem` | Custom key path (mode 4) |

See [`.env.example`](.env.example) for the full list with documentation,
and [docs/ssl.md](docs/ssl.md) for the TLS mode walkthrough.

## Usage

### npm Registry (Verdaccio)

```bash
# Register admin user (first user only — self-registration limited to 1)
npm adduser --registry http://localhost:9040

# Publish a package
npm publish --registry http://localhost:9040

# Project .npmrc (recommended)
@your-scope:registry=http://localhost:9040
```

### GitLab

```bash
# Clone
git clone http://localhost:9080/group/project.git

# Register CI runner (one-time)
./scripts/register-runner.sh <TOKEN>
```

### Harness-FE (AI Agent Gateway)

Connect your IDE agent to the shared gateway:

```json
{
  "mcpServers": {
    "harness-fe": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@harness-fe/cli", "mcp", "--gateway", "http://localhost:9050"]
    }
  }
}
```

In your frontend project:

```bash
pnpm add -D @harness-fe/vite @harness-fe/runtime
npx @harness-fe/skill install
```

### Bit Components

```bash
# workspace.jsonc → "remotes": { "dev-infra": "http://localhost:9030" }
bit add src/components/button
bit tag button --patch
bit export
```

## Operations

```bash
./scripts/healthcheck.sh        # Check all services
./scripts/backup.sh             # Backup data
./scripts/gen-certs.sh          # Generate Root CA + TLS certificates
docker compose logs -f <svc>    # Stream logs
docker compose restart <svc>    # Restart one service
docker compose down             # Stop everything
```

## Documentation

| Document | Description |
|----------|-------------|
| [docs/harness-fe.md](docs/harness-fe.md) | Harness-FE integration guide |
| [docs/verdaccio.md](docs/verdaccio.md) | npm registry admin guide |
| [docs/ssl.md](docs/ssl.md) | Caddy reverse proxy & TLS mode walkthrough |
| [docs/dns.md](docs/dns.md) | DNS configuration for custom domains |
| [docs/operations.md](docs/operations.md) | Day-to-day operations |

## Project Structure

```
├── .env.example              # Configuration template
├── .env.demo                 # Demo/staging preset
├── docker-compose.yml        # Service definitions
├── caddy/Caddyfile           # Reverse proxy config
├── verdaccio/config.yaml     # npm registry config
├── certs/                    # Custom TLS certificates (optional)
├── scripts/
│   ├── healthcheck.sh
│   ├── backup.sh
│   ├── gen-certs.sh              # Generate Root CA + server certs
│   ├── register-runner.sh
│   └── start-bit-scope.sh
├── data/                     # Runtime data (gitignored)
└── docs/
```

## License

MIT
