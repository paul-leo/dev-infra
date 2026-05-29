# Security Checklist

- [ ] Services are not exposed to the public internet.
- [ ] Docker ports bind to the LAN IP, not `0.0.0.0`.
- [ ] Firewall allows only trusted LAN/VPN ranges.
- [ ] GitLab public signup is disabled.
- [ ] GitLab projects default to private.
- [ ] Verdaccio requires authentication.
- [ ] No real tokens are committed.
- [ ] Backups stay on approved company storage.
- [ ] DNS API tokens and TLS private keys are not committed.
- [ ] GitLab root password is changed after first login.
- [ ] Personal access tokens have expiration dates.
- [ ] Departing users are removed from GitLab/Verdaccio.
- [ ] Packages are checked before publish: no `src`, `test`, `*.map`, secrets, or internal docs unless intentionally private.

