#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
Restore is intentionally manual.

GitLab restore outline:
1. Stop write traffic.
2. Copy the GitLab backup tar into data/gitlab/data/backups.
3. Run:
   docker compose exec gitlab gitlab-backup restore BACKUP=<timestamp>
4. Restore config from backups/<stamp>/config-and-verdaccio.tgz.
5. Restart:
   docker compose restart

Always test restore on a disposable machine before trusting backups.
EOF

