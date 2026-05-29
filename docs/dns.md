# LAN Access

Use direct LAN IP access while DNS is not configured.

```text
https://gitlab.internal.local -> GitLab
https://bit.internal.local -> Bit scope server
https://npm.internal.local -> Bit Cloud registry proxy
```

If DNS is added later, keep it internal-only and map hostnames to these same ports.
