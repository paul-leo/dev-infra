# DNS Setup (Optional)

By default, services are accessible via `localhost` and port numbers. If you want clean hostnames on your LAN, configure internal DNS.

## Example Hostnames

```text
gitlab.dev.local  →  <your-host-ip>
bit.dev.local     →  <your-host-ip>
npm.dev.local     →  <your-host-ip>
```

## Options

- **Router DNS override** — simplest for home/small office
- **Pi-hole / AdGuard Home** — if you already run one
- **dnsmasq / CoreDNS** — lightweight dedicated DNS
- `/etc/hosts` — single-machine only

## Single Machine Quick Test

Add to `/etc/hosts`:

```text
127.0.0.1 gitlab.dev.local bit.dev.local npm.dev.local
```

> Note: With port-based access (the default), DNS is not required. It's only useful if you add a reverse proxy that routes by hostname.
