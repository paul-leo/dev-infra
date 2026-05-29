# TLS

`.dev` domains require HTTPS in modern browsers.

## Option A: Internal CA

Use a trusted internal CA and place the wildcard certificate here:

```text
caddy/certs/internal.local.crt
caddy/certs/internal.local.key
```

The certificate should cover:

```text
*.internal.local
internal.local
```

All client devices must trust the internal CA.

## Option B: Let's Encrypt DNS-01

DNS-01 can issue valid public certificates without exposing HTTP ports.

Use this only if the DNS provider API token can be stored securely on the company computer.

Avoid HTTP-01 because it requires public inbound access.

