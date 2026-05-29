# TLS

Use this for the current local setup and for any later external HTTPS entry point.

## Option A: Internal CA

Let Caddy generate its own internal CA for local testing, or replace it with a trusted internal CA if your company already has one.

The certificate should cover:

```text
*.internal.local
internal.local
```

All client devices must trust the internal CA if you want browser-grade HTTPS without warnings.
For this repository's current localhost-only setup, trusting the local machine is enough.

## Option B: Let's Encrypt DNS-01

DNS-01 can issue valid public certificates without exposing HTTP ports.

Use this only if the DNS provider API token can be stored securely on the company computer and you are publishing a real external hostname.

Avoid HTTP-01 because it requires public inbound access.
