# dev-infra

A Docker Compose stack for self-hosted development infrastructure on your local network. One command gives you:

- **GitLab CE** — private Git hosting + built-in package registry
- **GitLab Runner** — CI/CD pipeline executor (Docker-in-Docker)
- **Bit Scope Server** — self-hosted [Bit](https://bit.dev) component server
- **Verdaccio** — lightweight private npm registry
- **Harness-FE** — AI agent MCP gateway ([harness-fe](https://github.com/Morphicai/harness-fe))

All services bind to `127.0.0.1` by default (localhost only). Change `HOST_IP` to expose on your LAN.

## Quick Start

```bash
# 1. Clone
git clone https://github.com/paul-leo/dev-infra.git
cd dev-infra

# 2. Configure
cp .env.example .env
# Edit .env — at minimum change GITLAB_ROOT_PASSWORD

# 3. Start all services
docker compose up -d

# Or start only what you need:
docker compose up -d                          # core only (verdaccio + harness)
docker compose --profile gitlab up -d         # + GitLab + Runner
docker compose --profile bit up -d            # + Bit scope server
docker compose --profile all up -d            # everything
```

Or set `COMPOSE_PROFILES` in `.env` to control which services start by default:

```env
# Only core + gitlab (no bit)
COMPOSE_PROFILES=gitlab

# Everything
COMPOSE_PROFILES=all
```

GitLab takes 3–5 minutes to initialize on first boot.

## Services

| Service | Port | URL | Profile |
|---------|------|-----|---------|
| Verdaccio | 9040 | http://localhost:9040 | *(core, always on)* |
| Harness-FE | 9050 | http://localhost:9050 | *(core, always on)* |
| Harness WS | 9051 | ws://localhost:9051 | *(core, always on)* |
| GitLab | 9080 | http://localhost:9080 | `gitlab` |
| GitLab SSH | 9022 | ssh://localhost:9022 | `gitlab` |
| GitLab Runner | — | — | `gitlab` |
| Bit Server | 9030 | http://localhost:9030 | `bit` |

**Core 服务**（verdaccio + harness）始终启动，其他通过 profile 按需开启。

## Configuration

All settings live in `.env`. Key variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `ENV_MODE` | `development` | Environment mode: development / staging / production |
| `HOST_IP` | `127.0.0.1` | Bind address. Use `0.0.0.0` or a LAN IP for team access |
| `BASE_DOMAIN` | `localhost` | Base domain for all services |
| `GITLAB_PORT` | `9080` | GitLab web port |
| `GITLAB_SSH_PORT` | `9022` | GitLab SSH port |
| `GITLAB_EXTERNAL_URL` | `http://localhost:9080` | Must match HOST_IP:GITLAB_PORT |
| `GITLAB_ROOT_PASSWORD` | *(required)* | Initial root password |
| `BIT_PORT` | `9030` | Bit scope server port |
| `BIT_SCOPE_NAME` | `dev-infra` | Bit scope name |
| `VERDACCIO_PORT` | `9040` | Verdaccio npm registry port |
| `HARNESS_PORT` | `9050` | Harness-FE gateway HTTP port |
| `HARNESS_WS_PORT` | `9051` | Harness-FE gateway WebSocket port |
| `HARNESS_MODE` | `solo` | Gateway mode: `solo` (local) or `governed` (team RBAC) |

### LAN / Team Setup

```env
HOST_IP=192.168.1.100
BASE_DOMAIN=192.168.1.100
GITLAB_EXTERNAL_URL=http://192.168.1.100:9080
```

### Demo Environment

For quick demo/staging deployments with HTTPS and LAN access:

```bash
cp .env.demo .env
# Edit passwords, then:
docker compose up -d
# Optionally enable HTTPS:
cp docker-compose.override.yml.example docker-compose.override.yml
docker compose up -d
```

### HTTPS with Custom Domains

```bash
# 1. Enable HTTPS
cp docker-compose.override.yml.example docker-compose.override.yml

# 2. Configure in .env
ENABLE_HTTPS=true
BASE_DOMAIN=dev.yourcompany.com
TLS_MODE=internal   # or: acme, custom

# 3. For custom certs, place files in ./certs/
#    CUSTOM_CERT_PATH=./certs/cert.pem
#    CUSTOM_KEY_PATH=./certs/key.pem

# 4. Start
docker compose up -d
```

## Usage

### GitLab

```bash
# Clone via HTTP
git clone http://localhost:9080/your-group/your-project.git

# Clone via SSH
git clone ssh://git@localhost:9022/your-group/your-project.git
```

### GitLab Runner

The runner container starts automatically but needs one-time registration:

1. GitLab → Admin → CI/CD → Runners → **New instance runner**
2. Copy the token
3. Run:

```bash
./scripts/register-runner.sh <TOKEN>
```

### Bit Components

```bash
# Install Bit CLI
npm i -g @teambit/bvm && bvm install

# In your project workspace.jsonc
# "defaultScope": "dev-infra"
# "remotes": { "dev-infra": "http://localhost:9030" }

# Workflow
bit add src/components/button
bit tag button --patch
bit export
```

### Verdaccio (npm Registry)

```bash
# Point npm to local registry
npm set registry http://localhost:9040

# Publish
npm publish --registry http://localhost:9040

# .npmrc for scoped packages
@dev-infra:registry=http://localhost:9040
@harness-fe:registry=http://localhost:9040
```

### Harness-FE (AI Agent Gateway)

The Harness-FE gateway connects AI agents (Claude, Cursor, Kiro) to your running applications via MCP.

```bash
# In your frontend project, install harness-fe:
pnpm add -D @harness-fe/vite @harness-fe/runtime

# Wire MCP in your agent's .mcp.json (point to the shared gateway):
```

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

For governed (team) mode with RBAC tokens:

```env
HARNESS_MODE=governed
HARNESS_AUTH_TOKEN=your-team-token
```

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/healthcheck.sh` | Check if services are responding |
| `scripts/backup.sh` | Backup GitLab + Bit data |
| `scripts/register-runner.sh` | Register GitLab Runner (run once) |
| `scripts/start-bit-scope.sh` | Bit container entrypoint (internal) |

## Data & Backups

Runtime data is stored in `data/` (gitignored). Back up with:

```bash
./scripts/backup.sh
```

Backups are saved to `backups/<timestamp>/`.

## Operations

```bash
# Stop all services
docker compose down

# View logs
docker compose logs -f gitlab
docker compose logs -f bit
docker compose logs -f harness

# Upgrade images
# 1. Edit image tags in .env
# 2. docker compose pull
# 3. docker compose up -d
```

## License

MIT
