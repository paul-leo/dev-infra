# Project Plan

## Purpose

This project defines a private, company-computer-hosted development infrastructure for internal project related work.

The goal is to provide a controlled local/LAN environment for:

- private Git hosting
- private package/component distribution
- Bit-based build and preview workflows
- internal-only experimentation with SDK, bot, MCP, and OpenClaw integration packages

This project is not intended to expose company code or services to the public internet.

## Compliance Boundary

The infrastructure is designed for company-device and company-network use.

Allowed:

- hosting private repositories on a company computer or approved company LAN host
- using internal DNS names that resolve only inside the LAN/VPN
- storing internal project source code and private packages inside the internal environment
- using local Bit CLI workflows for build, tag, preview, and package generation
- publishing packages only to private internal registries

Not allowed:

- exposing GitLab, Bit, npm registry, or package artifacts to the public internet
- publishing internal project packages to public Bit Cloud, npm, GitHub, GitLab.com, or other third-party SaaS without approval
- committing real tokens, storage files, test account credentials, private keys, or internal secrets
- treating obfuscation, WASM, or sourcemaps removal as a substitute for access control
- taking company code, real API details, tokens, package artifacts, or Git history outside company-approved environments

If a portable personal learning artifact is needed, it should be a separate clean-room project using a mock server and neutral naming.

## Requirements

### Functional Requirements

- Provide private Git hosting for internal project repositories.
- Provide private npm/package hosting for generated packages.
- Support local Bit workflows:
  - `bit build`
  - `bit start`
  - `bit tag`
  - package generation and private publishing
- Support internal HTTPS access for `.dev` hostnames.
- Support backup and restore procedures.
- Support health checks for the core services.
- Keep configuration in Git while excluding runtime data and secrets.

### Security Requirements

- Services must not be reachable from the public internet.
- DNS records for service hostnames must resolve only through internal DNS or controlled split-horizon DNS.
- All repositories and packages must default to private.
- Anonymous access and public self-registration must be disabled.
- TLS private keys, DNS provider API tokens, and service secrets must never be committed.
- GitLab root password must be changed after initial setup.
- Users and tokens must have explicit expiration and removal procedures.
- Package publishing must be guarded by a release checklist.

### Operational Requirements

- Deployment should be reproducible from Docker Compose configuration.
- Runtime data should live under ignored local directories.
- Backup commands should be documented and scriptable.
- Restore should remain an explicit manual process until tested.
- Upgrades should be planned and reversible.
- The system should be easy to shut down, migrate, or hand over.

## Technical Plan

### Phase 1: Private Git and Package Baseline

Use:

- GitLab CE for source control and GitLab Package Registry
- Caddy as the internal HTTPS reverse proxy
- Internal DNS for service names

Initial hostnames:

```text
gitlab.internal.local
npm.internal.local
bit.internal.local
```

For the first phase, Bit remains primarily a local CLI workflow. Package distribution can use GitLab Package Registry or Verdaccio.

### Phase 2: Private npm Registry

Add Verdaccio if GitLab Package Registry is not ergonomic enough for local package workflows.

Use Verdaccio for:

- scoped internal packages
- quick local publish/install tests
- isolated package experiments

Keep GitLab as the canonical source repository.

### Phase 3: Bit Service POC

Evaluate whether a self-hosted Bit service is necessary.

Before adopting it, confirm:

- private scope behavior
- package registry integration
- backup model
- user and permission model
- whether package contents expose source files, tests, or sourcemaps

Do not make Bit service the source of truth until the GitLab/npm flow is stable.

### Phase 4: Package Hardening

Before broader internal installation, harden package output:

- strict `files` allowlists
- no `src/**` in install packages unless intentionally required
- no `test/**`
- no `*.map`
- no `*.tsbuildinfo`
- no local storage files
- no internal-only docs in package artifacts unless approved

Sensitive logic should be moved to an internal service if it cannot be safely distributed to installed clients.

## DNS and TLS Strategy

Recommended DNS model:

```text
gitlab.internal.local -> company computer LAN IP
npm.internal.local    -> company computer LAN IP
bit.internal.local    -> company computer LAN IP
```

These records should be internal-only.

Because `.dev` requires HTTPS, use one of:

- internal CA certificates trusted by company devices
- DNS-01 issued wildcard certificates

Do not use HTTP-01 challenges, because they require public inbound access.

## Exit and Handover Policy

This infrastructure is for company-context development.

If the maintainer leaves or the machine is retired:

- remove personal access
- rotate service credentials
- transfer GitLab and registry admin ownership
- delete local tokens and storage files
- preserve or remove repositories according to company direction
- do not export internal project code or package artifacts to personal systems

Portable learning should be maintained in a separate clean-room repository.

