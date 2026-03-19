#!/usr/bin/env bash

set -euo pipefail

CCMAN_REAL_BIN="${CCMAN_REAL_BIN:-/usr/local/bin/ccman-real}"
NODE_HOME="/home/node"
NODE_XDG_CONFIG_HOME="${NODE_HOME}/.config"

if [[ ! -x "${CCMAN_REAL_BIN}" ]]; then
  echo "ccman real binary not found: ${CCMAN_REAL_BIN}" >&2
  exit 1
fi

if [[ "$(id -u)" == "0" ]]; then
  exec gosu node env \
    HOME="${NODE_HOME}" \
    USER=node \
    LOGNAME=node \
    XDG_CONFIG_HOME="${NODE_XDG_CONFIG_HOME}" \
    NODE_ENV=production \
    "${CCMAN_REAL_BIN}" "$@"
fi

exec env \
  HOME="${NODE_HOME}" \
  USER=node \
  LOGNAME=node \
  XDG_CONFIG_HOME="${NODE_XDG_CONFIG_HOME}" \
  NODE_ENV=production \
  "${CCMAN_REAL_BIN}" "$@"
