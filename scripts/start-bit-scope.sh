#!/usr/bin/env sh
set -eu

SCOPE_NAME="${BIT_SCOPE_NAME:-internal-project}"
SCOPE_DIR="/root/${SCOPE_NAME}"

cd "$SCOPE_DIR"

if [ ! -f scope.json ]; then
  echo "[bit] initializing bare scope: ${SCOPE_NAME}"
  bit init --bare
fi

exec bit start
