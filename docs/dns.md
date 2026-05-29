# Internal DNS

Use split-horizon DNS. These records should resolve inside the company LAN only.

```text
gitlab.internal.local  A  <company-computer-lan-ip>
npm.internal.local     A  <company-computer-lan-ip>
bit.internal.local     A  <company-computer-lan-ip>
```

Recommended local DNS options:

- Router DNS override
- dnsmasq
- Pi-hole
- AdGuard Home
- CoreDNS

Do not point these hostnames to an IP you do not control.

For a single-machine test, `/etc/hosts` is acceptable:

```text
192.168.1.100 gitlab.internal.local npm.internal.local bit.internal.local
```

