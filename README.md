# dev-infra

A Docker Compose stack for self-hosted development infrastructure on your local network. One command gives you:

- **GitLab CE** — private Git hosting + built-in package registry
- **GitLab Runner** — CI/CD pipeline executor (Docker-in-Docker)
- **Bit Scope Server** — self-hosted [Bit](https://bit.dev) component server
- **Verdaccio** — lightweight private npm registry

All services bind to `127.0.0.1` by default (localhost only). Change `HOST_IP` to expose on your LAN.

## Quick Start

```bash
# 1. Clone
git clone https://github.com/paul-leo/dev-infra.git
cd dev-infra

# 2. Configure
cp .env.example .env
# Edit .env — at minimum change GITLAB_ROOT_PASSWORD

# 3. Start
docker compose up -d
```

GitLab takes 3–5 minutes to initialize on first boot.

## Services

| Service | Default URL | Notes |
|---------|-------------|-------|
| GitLab | http://localhost:8080 | Login: `root` / your password |
| GitLab SSH | ssh://localhost:9022 | Add your SSH key in GitLab first |
| Bit Server | http://localhost:3000 | Scope: `dev-infra` |
| Verdaccio | http://localhost:4873 | npm registry with web UI |

## Configuration

All settings live in `.env`. Key variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST_IP` | `127.0.0.1` | Bind address. Use `0.0.0.0` or a LAN IP for team access |
| `GITLAB_PORT` | `8080` | GitLab web port |
| `GITLAB_SSH_PORT` | `9022` | GitLab SSH port |
| `GITLAB_EXTERNAL_URL` | `http://localhost:8080` | Must match HOST_IP:GITLAB_PORT |
| `GITLAB_ROOT_PASSWORD` | *(required)* | Initial root password |
| `BIT_PORT` | `3000` | Bit scope server port |
| `BIT_SCOPE_NAME` | `dev-infra` | Bit scope name |
| `VERDACCIO_PORT` | `4873` | Verdaccio npm registry port |

### LAN / Team Setup

```env
HOST_IP=192.168.1.100
GITLAB_EXTERNAL_URL=http://192.168.1.100:8080
```

## Usage

### GitLab

```bash
# Clone via HTTP
git clone http://localhost:8080/your-group/your-project.git

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
# "remotes": { "dev-infra": "http://localhost:3000" }

# Workflow
bit add src/components/button
bit tag button --patch
bit export
```

### Verdaccio (npm Registry)

```bash
# Point npm to local registry
npm set registry http://localhost:4873

# Publish
npm publish --registry http://localhost:4873

# .npmrc for scoped packages
@dev-infra:registry=http://localhost:4873
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

## HTTPS (Optional)

For HTTPS, put a reverse proxy in front. See `caddy/Caddyfile` for a Caddy example, or use Nginx/Traefik.

## Operations

```bash
# Stop all services
docker compose down

# View logs
docker compose logs -f gitlab
docker compose logs -f bit

# Upgrade images
# 1. Edit image tags in .env
# 2. docker compose pull
# 3. docker compose up -d
```

## License

MIT
