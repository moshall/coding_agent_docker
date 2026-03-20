#!/usr/bin/env bash
# Host-side health check for a running coding-agent container.
# Usage:
#   ./scripts/healthcheck.sh [container_name]
# Env:
#   CONTAINER_NAME  default: coding-agent
set -euo pipefail

CONTAINER_NAME="${1:-${CONTAINER_NAME:-coding-agent}}"

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

check() {
  local name="$1"
  local cmd="$2"
  local out rc
  if out="$(bash -lc "${cmd}" 2>&1)"; then
    rc=0
  else
    rc=$?
  fi
  local first
  first="$(printf '%s' "${out}" | head -n 1)"
  if [[ ${rc} -eq 0 ]]; then
    log_pass "${name}${first:+ :: ${first}}"
  else
    log_fail "${name}${first:+ :: ${first}}"
  fi
}

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker not found on host PATH" >&2
  exit 2
fi

if ! docker inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
  echo "error: container not found: ${CONTAINER_NAME}" >&2
  exit 2
fi

echo "== Health Check: ${CONTAINER_NAME} =="

check "container running" "docker inspect '${CONTAINER_NAME}' --format '{{.State.Status}}' | grep -qx running"
check "pid1 is node" "docker exec '${CONTAINER_NAME}' ps -o user= -p 1 | tr -d '[:space:]' | grep -qx node"
check "restart count stable" "docker inspect '${CONTAINER_NAME}' --format '{{.RestartCount}}' | grep -Eq '^[0-9]+$'"
check "cron process" "docker exec '${CONTAINER_NAME}' pgrep -x cron >/dev/null"

if docker exec "${CONTAINER_NAME}" sh -lc 'command -v tailscaled >/dev/null 2>&1' >/dev/null 2>&1; then
  if docker exec "${CONTAINER_NAME}" sh -lc '[ -e /dev/net/tun ]' >/dev/null 2>&1; then
    check "tailscaled process" "docker exec '${CONTAINER_NAME}' pgrep -x tailscaled >/dev/null"
  else
    log_skip "tailscaled process :: /dev/net/tun missing"
  fi
else
  log_skip "tailscaled process :: tailscaled not installed"
fi

cloudcli_enable="$(docker exec "${CONTAINER_NAME}" sh -lc 'printf %s "${CLOUDCLI_ENABLE:-true}"' 2>/dev/null || true)"
cloudcli_enable_lc="$(printf '%s' "${cloudcli_enable}" | tr '[:upper:]' '[:lower:]')"
cloudcli_port="$(docker exec "${CONTAINER_NAME}" sh -lc 'printf %s "${CLOUDCLI_PORT:-3001}"' 2>/dev/null || true)"
cloudcli_port="${cloudcli_port:-3001}"

if [[ "${cloudcli_enable_lc}" == "false" || "${cloudcli_enable_lc}" == "0" || "${cloudcli_enable_lc}" == "no" || "${cloudcli_enable_lc}" == "off" ]]; then
  log_skip "cloudcli checks :: CLOUDCLI_ENABLE=${cloudcli_enable:-false}"
else
  check "cloudcli CLI" "docker exec '${CONTAINER_NAME}' sh -lc 'cloudcli version'"
  check "cloudcli listening" "docker exec '${CONTAINER_NAME}' sh -lc 'if command -v ss >/dev/null 2>&1; then ss -ltn 2>/dev/null | awk \"{print \\\$4}\" | grep -Eq \"[:.]${cloudcli_port}\\\$\"; elif command -v netstat >/dev/null 2>&1; then netstat -ltn 2>/dev/null | awk \"{print \\\$4}\" | grep -Eq \"[:.]${cloudcli_port}\\\$\"; elif command -v python3 >/dev/null 2>&1; then python3 -c \"import socket,sys; s=socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.settimeout(0.5); rc=s.connect_ex((\\\"127.0.0.1\\\", int(sys.argv[1]))); s.close(); raise SystemExit(0 if rc == 0 else 1)\" \"${cloudcli_port}\"; else false; fi'"
  check "cloudcli HTTP" "docker exec '${CONTAINER_NAME}' sh -lc 'curl -fsS \"http://127.0.0.1:${cloudcli_port}/\" >/dev/null'"
fi

echo "Summary: pass=${PASS_COUNT} fail=${FAIL_COUNT} skip=${SKIP_COUNT}"
if [[ ${FAIL_COUNT} -gt 0 ]]; then
  exit 1
fi
