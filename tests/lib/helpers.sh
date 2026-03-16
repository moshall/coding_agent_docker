#!/usr/bin/env bash

set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

log_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "PASS: $*"
}

log_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "FAIL: $*" >&2
}

log_skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  echo "SKIP: $*"
}

require_cmd() {
  local cmd=$1
  command -v "${cmd}" >/dev/null 2>&1
}

run_check() {
  local name=$1
  shift
  if "$@"; then
    log_pass "${name}"
  else
    log_fail "${name}"
  fi
}

run_or_skip_no_docker() {
  if ! require_cmd docker; then
    log_skip "docker not available"
    return 0
  fi
  "$@"
}

summary_and_exit() {
  echo "Summary: pass=${PASS_COUNT} fail=${FAIL_COUNT} skip=${SKIP_COUNT}"
  if [[ ${FAIL_COUNT} -gt 0 ]]; then
    exit 1
  fi
}
