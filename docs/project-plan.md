# Project Plan

## Purpose

This project defines a private, company-computer-hosted development infrastructure for internal project related work.

The goal is to provide a controlled local/LAN environment for:

- private Git hosting
- private Bit component and npm package distribution
- Bit-based build and preview workflows
- internal-only experimentation with SDK, bot, MCP, and OpenClaw integration packages

This project is not intended to expose company code or services to the public internet.

## Compliance Boundary

The infrastructure is designed for company-device and company-network use.

Allowed:

- hosting private repositories on a company computer or approved company LAN host
- using direct LAN IP access when DNS is not configured yet
- storing internal project source code and private packages inside the internal environment
- using local Bit CLI workflows for build, tag, preview, and package generation
- publishing packages through Bit Cloud and the self-hosted Bit scope server only

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
- Provide private Bit component hosting and npm package distribution for generated packages.
- Support local Bit workflows:
  - `bit build`
  - `bit start`
  - `bit tag`
  - package generation and private publishing
- Support internal HTTPS access via LAN IP and fixed service ports.
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

### Phase 1: Private Git Baseline

Use:

- GitLab CE for source control
- Caddy as the internal HTTP reverse proxy
- Internal DNS for service names

Initial hostnames:

```text
https://gitlab.internal.local
https://bit.internal.local
https://npm.internal.local
```

For the first phase, Bit remains primarily a local CLI workflow while the self-hosted Bit service is evaluated.

### Phase 2: Bit Cloud Package Distribution

Use Bit Cloud as the primary npm/package distribution target.

Target responsibilities:

- private Bit scopes
- component browsing and discovery
- generated npm package distribution
- authenticated internal installs
- package access control
- package metadata and version discovery

GitLab remains the canonical source repository. Bit Cloud is the package/component distribution layer.

### Phase 3: Self-Hosted Bit Scope Server

Use the self-hosted Bit scope server for internal component hosting and scope management.

Before broader use, confirm:

- private scope behavior
- backup model
- user and permission model
- how component metadata maps to Bit Cloud package installs

### Phase 4: Bit Service Hardening

Before adopting the self-hosted Bit service for broader internal use, confirm:

- private scope behavior
- backup model
- user and permission model
- whether package contents expose source files, tests, or sourcemaps

Do not make the Bit service broadly available until access control, backup, restore, and package contents are verified.

### Phase 5: Package Hardening

Before broader internal installation, harden package output:

- strict `files` allowlists
- no `src/**` in install packages unless intentionally required
- no `test/**`
- no `*.map`
- no `*.tsbuildinfo`
- no local storage files
- no internal-only docs in package artifacts unless approved

Sensitive logic should be moved to an internal service if it cannot be safely distributed to installed clients.

## Access Strategy

Recommended LAN access model:

```text
https://gitlab.internal.local -> GitLab
https://bit.internal.local -> Bit scope server
https://npm.internal.local -> Bit Cloud registry proxy
```

When DNS is configured later, you may map those ports through internal-only hostnames.

If a public or externally reachable entry point is added later, place HTTPS there and keep LAN access separate.

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
