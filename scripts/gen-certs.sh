#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# gen-certs.sh — Generate a self-signed Root CA + service certificates
#
# Creates a local CA and issues wildcard + SAN certificates for all services.
# Useful for internal/LAN deployments where Let's Encrypt isn't available.
#
# Usage:
#   ./scripts/gen-certs.sh                     # uses BASE_DOMAIN from .env
#   ./scripts/gen-certs.sh dev.local           # explicit domain
#   ./scripts/gen-certs.sh 192.168.1.100       # IP-based cert
#
# Output (in ./certs/):
#   ca.crt, ca.key          — Root CA (distribute to clients to trust)
#   cert.pem, key.pem       — Server certificate (used by Caddy or services)
#
# To trust the CA on client machines, see docs/ssl.md
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERTS_DIR="$ROOT_DIR/certs"

# Load domain from argument, .env, or default
if [[ -n "${1:-}" ]]; then
  DOMAIN="$1"
elif [[ -f "$ROOT_DIR/.env" ]]; then
  DOMAIN=$(grep -E '^BASE_DOMAIN=' "$ROOT_DIR/.env" | cut -d= -f2 | tr -d '"' | tr -d "'")
  DOMAIN="${DOMAIN:-localhost}"
else
  DOMAIN="localhost"
fi

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Generating TLS certificates for: $DOMAIN"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

mkdir -p "$CERTS_DIR"

# ─── Step 1: Generate Root CA ────────────────────────────────────────────────
if [[ -f "$CERTS_DIR/ca.crt" && -f "$CERTS_DIR/ca.key" ]]; then
  echo "[✓] Root CA already exists, reusing: $CERTS_DIR/ca.crt"
else
  echo "[*] Generating Root CA..."
  openssl genrsa -out "$CERTS_DIR/ca.key" 4096 2>/dev/null

  openssl req -x509 -new -nodes \
    -key "$CERTS_DIR/ca.key" \
    -sha256 -days 3650 \
    -out "$CERTS_DIR/ca.crt" \
    -subj "/C=CN/ST=DevInfra/L=Local/O=dev-infra/OU=CA/CN=dev-infra Root CA"

  echo "[✓] Root CA created (valid 10 years)"
fi

# ─── Step 2: Generate Server Certificate ─────────────────────────────────────
echo "[*] Generating server certificate for: $DOMAIN"

# Build SAN (Subject Alternative Names) list
SAN_ENTRIES="DNS:${DOMAIN},DNS:*.${DOMAIN}"
SAN_ENTRIES="${SAN_ENTRIES},DNS:gitlab.${DOMAIN},DNS:npm.${DOMAIN},DNS:bit.${DOMAIN},DNS:harness.${DOMAIN}"
SAN_ENTRIES="${SAN_ENTRIES},DNS:localhost,DNS:*.localhost"

# If domain looks like an IP, add IP SAN
if echo "$DOMAIN" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
  SAN_ENTRIES="${SAN_ENTRIES},IP:${DOMAIN},IP:127.0.0.1"
else
  SAN_ENTRIES="${SAN_ENTRIES},IP:127.0.0.1"
fi

# Generate private key
openssl genrsa -out "$CERTS_DIR/key.pem" 2048 2>/dev/null

# Generate CSR
openssl req -new \
  -key "$CERTS_DIR/key.pem" \
  -out "$CERTS_DIR/server.csr" \
  -subj "/C=CN/ST=DevInfra/L=Local/O=dev-infra/OU=Server/CN=${DOMAIN}"

# Create extensions config
cat > "$CERTS_DIR/ext.cnf" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = ${SAN_ENTRIES}
EOF

# Sign with Root CA
openssl x509 -req \
  -in "$CERTS_DIR/server.csr" \
  -CA "$CERTS_DIR/ca.crt" \
  -CAkey "$CERTS_DIR/ca.key" \
  -CAcreateserial \
  -out "$CERTS_DIR/cert.pem" \
  -days 825 \
  -sha256 \
  -extfile "$CERTS_DIR/ext.cnf" 2>/dev/null

# Create fullchain (cert + CA)
cat "$CERTS_DIR/cert.pem" "$CERTS_DIR/ca.crt" > "$CERTS_DIR/fullchain.pem"

# Cleanup temp files
rm -f "$CERTS_DIR/server.csr" "$CERTS_DIR/ext.cnf" "$CERTS_DIR/ca.srl"

echo "[✓] Server certificate created (valid 825 days)"
echo ""
echo "─── Generated Files ──────────────────────────────────────────────"
echo ""
echo "  Root CA (distribute to clients):"
echo "    $CERTS_DIR/ca.crt"
echo "    $CERTS_DIR/ca.key          ← keep secret!"
echo ""
echo "  Server Certificate (used by Caddy/services):"
echo "    $CERTS_DIR/cert.pem        ← server cert"
echo "    $CERTS_DIR/key.pem         ← private key"
echo "    $CERTS_DIR/fullchain.pem   ← cert + CA chain"
echo ""
echo "─── SAN (Subject Alternative Names) ─────────────────────────────"
echo ""
echo "  $SAN_ENTRIES" | tr ',' '\n' | sed 's/^/    /'
echo ""
echo "─── Next Steps ──────────────────────────────────────────────────"
echo ""
echo "  1. Trust the CA on client machines:"
echo ""
echo "     macOS:   sudo security add-trusted-cert -d -r trustRoot \\"
echo "                -k /Library/Keychains/System.keychain $CERTS_DIR/ca.crt"
echo ""
echo "     Linux:   sudo cp $CERTS_DIR/ca.crt /usr/local/share/ca-certificates/dev-infra.crt"
echo "              sudo update-ca-certificates"
echo ""
echo "     Windows: Import-Certificate -FilePath ca.crt -CertStoreLocation Cert:\\LocalMachine\\Root"
echo ""
echo "  2. Enable Caddy with custom certs in .env:"
echo "     COMPOSE_PROFILES=caddy"
echo "     CUSTOM_CERT_PATH=./certs/fullchain.pem"
echo "     CUSTOM_KEY_PATH=./certs/key.pem"
echo ""
echo "  3. Or use direct port access (certs not required):"
echo "     http://${DOMAIN}:9080  (GitLab)"
echo "     http://${DOMAIN}:9040  (Verdaccio)"
echo ""
