# TLS / HTTPS (Optional)

The default setup runs over plain HTTP, which is fine for localhost or a trusted LAN. Add TLS if you need HTTPS.

## Option A: Caddy Internal CA

Let Caddy generate self-signed certificates automatically:

```caddyfile
gitlab.dev.local {
  tls internal
  reverse_proxy localhost:8080
}
```

Clients must trust Caddy's root CA to avoid browser warnings.

## Option B: Let's Encrypt (DNS-01)

If you own a real domain and want valid public certificates without opening inbound ports:

```caddyfile
gitlab.example.com {
  tls {
    dns cloudflare {env.CF_API_TOKEN}
  }
  reverse_proxy localhost:8080
}
```

Requires a custom Caddy build with your DNS provider plugin.

## Option C: Your Own Certificates

Mount your existing certs:

```caddyfile
gitlab.dev.local {
  tls /path/to/cert.pem /path/to/key.pem
  reverse_proxy localhost:8080
}
```
