#!/usr/bin/env bash

set -euo pipefail

REAL_BIN="/usr/local/bin/cloudcli-real"
port="${SERVER_PORT:-${CLOUDCLI_PORT:-3001}}"

is_port_listening() {
  local target_port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${target_port}$"
    return $?
  fi

  if command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${target_port}$"
    return $?
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "${target_port}" <<'PY'
import socket
import sys

port = int(sys.argv[1])
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.settimeout(0.5)
try:
    rc = sock.connect_ex(("127.0.0.1", port))
finally:
    sock.close()
sys.exit(0 if rc == 0 else 1)
PY
    return $?
  fi

  return 1
}

if [[ ! -x "${REAL_BIN}" ]]; then
  echo "[cloudcli-wrapper] missing binary: ${REAL_BIN}" >&2
  exit 127
fi

# In this image, cloudcli is auto-started by entrypoint by default.
# If user launches a second interactive instance without args, avoid EADDRINUSE noise.
if [[ $# -eq 0 ]] && [[ "${CLOUDCLI_ALLOW_SECOND_INSTANCE:-0}" != "1" ]]; then
  if is_port_listening "${port}"; then
    echo "[cloudcli-wrapper] cloudcli already listening on 0.0.0.0:${port}."
    echo "[cloudcli-wrapper] This image auto-starts cloudcli when CLOUDCLI_ENABLE=true."
    echo "[cloudcli-wrapper] Use the running service, or set CLOUDCLI_ENABLE=false to start manually."
    exit 0
  fi
fi

exec "${REAL_BIN}" "$@"
