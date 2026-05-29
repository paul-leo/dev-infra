#!/usr/bin/env sh
set -eu

cd /root/remote-scope

if [ ! -f .bitmap ]; then
  echo "[bit] initializing bare scope"
  bit init --bare
fi

exec bit start
