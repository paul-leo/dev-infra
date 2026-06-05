# TLS / HTTPS

HTTPS is provided by the built-in Caddy reverse proxy (enable with `--profile caddy`).

## How Caddy Handles TLS

Caddy automatically provisions certificates based on your domain:

| Domain Type | TLS Behavior | Example |
|-------------|-------------|---------|
| Public domain | Let's Encrypt (ACME) | `gitlab.dev.example.com` |
| `.local` / `.internal` | Self-signed internal CA | `gitlab.dev.local` |
| `localhost` | No TLS (plain HTTP) | `gitlab.localhost` |
| IP address | No TLS | `192.168.1.100` |

## Quick HTTPS Setup

### Self-Signed (LAN / Development)

```env
BASE_DOMAIN=dev.local
COMPOSE_PROFILES=gitlab,caddy
```

```bash
docker compose up -d
# Access: https://gitlab.dev.local (browser will warn about self-signed cert)
```

To trust the internal CA on your machine:

```bash
# Extract Caddy's root CA
docker compose cp caddy:/data/caddy/pki/authorities/local/root.crt ./caddy-root.crt

# macOS
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ./caddy-root.crt

# Linux
sudo cp ./caddy-root.crt /usr/local/share/ca-certificates/caddy.crt
sudo update-ca-certificates

# Windows (PowerShell as admin)
Import-Certificate -FilePath .\caddy-root.crt -CertStoreLocation Cert:\LocalMachine\Root
```

### Let's Encrypt (Public Domain)

Requirements:
- Domain DNS points to your server
- Ports 80 and 443 reachable from internet

```env
BASE_DOMAIN=dev.yourcompany.com
ACME_EMAIL=admin@yourcompany.com
COMPOSE_PROFILES=gitlab,caddy
```

Caddy auto-provisions and renews certificates. No manual steps needed.

### Custom Certificates

If you already have cert files (corporate CA, purchased certs):

1. Place files in `./certs/`:
   ```
   certs/cert.pem   # certificate or fullchain
   certs/key.pem    # private key
   ```

2. Update the Caddyfile to use them:
   ```caddyfile
   gitlab.example.com {
     tls /certs/cert.pem /certs/key.pem
     reverse_proxy gitlab:80
   }
   ```

## GitLab HTTPS Configuration

When using Caddy for HTTPS, update GitLab's external URL:

```env
GITLAB_EXTERNAL_URL=https://gitlab.dev.example.com
```

GitLab itself still runs plain HTTP internally; Caddy terminates TLS.

## Mixed Mode

You can access services both ways simultaneously:
- Via Caddy: `https://gitlab.dev.local` (port 443)
- Direct: `http://<ip>:9080` (no TLS)

This is useful during migration or for internal tooling that doesn't support custom CAs.

## Verifying TLS

```bash
# Check certificate
openssl s_client -connect gitlab.dev.local:443 -servername gitlab.dev.local </dev/null 2>/dev/null | openssl x509 -text -noout

# curl with verbose
curl -v https://gitlab.dev.local

# If using self-signed, skip verify for testing
curl -k https://gitlab.dev.local
```
