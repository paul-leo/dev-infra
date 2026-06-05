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

### Option A: Direct Port Access (default)

No DNS needed. Access services by IP + port:

```
http://localhost:9080   → GitLab
http://localhost:9040   → Verdaccio
http://localhost:9050   → Harness-FE
```

### Option B: Custom Domains + HTTPS

Enable Caddy and set your domain:

```env
COMPOSE_PROFILES=gitlab,caddy
BASE_DOMAIN=dev.example.com
ACME_EMAIL=admin@example.com   # for Let's Encrypt
```

Services become available at:

```
https://gitlab.dev.example.com
https://npm.dev.example.com
https://bit.dev.example.com
https://harness.dev.example.com
```

Caddy auto-provisions TLS certificates:
- **Public domains** → Let's Encrypt (requires DNS pointing to your server)
- **`.local` / `.internal`** → self-signed internal CA
- **`localhost`** → plain HTTP (no TLS)

### Option C: LAN with Local Domains

```env
HOST_IP=0.0.0.0
BASE_DOMAIN=dev.local
COMPOSE_PROFILES=all
```

Generate internal Root CA + certificates:

```bash
./scripts/gen-certs.sh
# Generates: certs/ca.crt, certs/cert.pem, certs/key.pem, certs/fullchain.pem
```

Trust the CA on client machines:

```bash
# macOS
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain ./certs/ca.crt

# Linux
sudo cp ./certs/ca.crt /usr/local/share/ca-certificates/dev-infra.crt
sudo update-ca-certificates

# Windows (PowerShell as admin)
Import-Certificate -FilePath .\certs\ca.crt -CertStoreLocation Cert:\LocalMachine\Root
```

Add to `/etc/hosts` on each client machine:

```
192.168.1.100  gitlab.dev.local npm.dev.local bit.dev.local harness.dev.local
```

### Custom Per-Service Domains

Override individual service domains:

```env
GITLAB_DOMAIN=code.mycompany.com
NPM_DOMAIN=registry.mycompany.com
HARNESS_DOMAIN=agent.mycompany.com
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
| `CADDY_HTTP_PORT` | `80` | Caddy HTTP |
| `CADDY_HTTPS_PORT` | `443` | Caddy HTTPS |
| `ACME_EMAIL` | — | Email for Let's Encrypt |

See [`.env.example`](.env.example) for the full list with documentation.

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
| [docs/ssl.md](docs/ssl.md) | TLS / HTTPS setup options |
| [docs/dns.md](docs/dns.md) | DNS configuration for custom domains |
| [docs/operations.md](docs/operations.md) | Day-to-day operations |
| [docs/agent-handbook.md](docs/agent-handbook.md) | AI agent deployment handbook |

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
