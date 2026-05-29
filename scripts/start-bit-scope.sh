#!/usr/bin/env sh
set -eu

cd /root/remote-scope

if [ ! -f scope.json ]; then
  echo "[bit] initializing bare scope"
  bit init --bare
fi

exec bit start
