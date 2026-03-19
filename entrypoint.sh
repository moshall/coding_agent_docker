#!/usr/bin/env bash

set -euo pipefail

if [[ "$(id -u)" != "0" ]]; then
  echo "[entrypoint] ERROR: must run as root" >&2
  exit 1
fi

DATA_ROOT="${DATA_ROOT:-/data/coding-agent}"
BOOTSTRAP_ROOT="${DATA_ROOT}/config/bootstrap"
GO_MARKER="${BOOTSTRAP_ROOT}/install-go-runtime"
BUILD_ESSENTIAL_MARKER="${BOOTSTRAP_ROOT}/install-build-essential"

log() {
  echo "[entrypoint] $*"
}

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

safe_start_cron() {
  if command -v service >/dev/null 2>&1; then
    service cron start >/dev/null 2>&1 || /etc/init.d/cron start >/dev/null 2>&1 || true
  else
    cron >/dev/null 2>&1 || true
  fi
}

maybe_start_tailscale() {
  if ! command -v tailscaled >/dev/null 2>&1; then
    log "tailscaled not found, skipping"
    return
  fi

  log "starting tailscaled..."
  tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock >/tmp/tailscaled.log 2>&1 &
  sleep 2

  if [[ -n "${TAILSCALE_AUTHKEY:-}" ]] && command -v tailscale >/dev/null 2>&1; then
    log "connecting to Tailscale..."
    tailscale up --authkey="${TAILSCALE_AUTHKEY}" --hostname="${TAILSCALE_HOSTNAME:-coding-agent}" || true
  fi
}

run_with_timeout_as_node() {
  local seconds="$1"
  local cmd="$2"
  if command -v timeout >/dev/null 2>&1; then
    timeout "${seconds}s" su node -s /bin/bash -c "${cmd}" || true
  else
    su node -s /bin/bash -c "${cmd}" || true
  fi
}

sync_repo_as_node() {
  local url="$1"
  local dest="$2"
  local label="$3"
  local seconds="${4:-180}"

  if [[ -d "${dest}/.git" ]]; then
    return
  fi

  log "syncing ${label} repo..."
  run_with_timeout_as_node "${seconds}" "tmp='${dest}.tmp'; rm -rf \"\${tmp}\"; git clone --depth 1 '${url}' \"\${tmp}\" && rm -rf '${dest}' && mv \"\${tmp}\" '${dest}'"
}

ensure_runtime_packages() {
  local install_go=0
  local install_build=0

  mkdir -p "${BOOTSTRAP_ROOT}"

  if [[ -f "${GO_MARKER}" ]] || is_truthy "${INSTALL_GO_RUNTIME:-}"; then
    install_go=1
    : >"${GO_MARKER}"
  fi

  if [[ -f "${BUILD_ESSENTIAL_MARKER}" ]] || is_truthy "${INSTALL_BUILD_ESSENTIAL:-}"; then
    install_build=1
    : >"${BUILD_ESSENTIAL_MARKER}"
  fi

  if [[ "${install_go}" -eq 0 && "${install_build}" -eq 0 ]]; then
    return
  fi

  local -a packages=()

  if [[ "${install_go}" -eq 1 ]] && ! command -v go >/dev/null 2>&1; then
    packages+=(golang)
  fi

  if [[ "${install_build}" -eq 1 ]] && ! dpkg-query -W -f='${Status}' build-essential 2>/dev/null | grep -q "install ok installed"; then
    packages+=(build-essential)
  fi

  if [[ "${#packages[@]}" -eq 0 ]]; then
    return
  fi

  log "installing optional runtime packages: ${packages[*]}"
  apt-get update
  apt-get install -y --no-install-recommends "${packages[@]}"
  rm -rf /var/lib/apt/lists/*
}

mkdir -p \
  /home/node/.ccman \
  /home/node/.claude \
  /home/node/.codex \
  /home/node/.gemini \
  /home/node/.config/gemini \
  /home/node/.config/opencode \
  /home/node/.openclaw \
  /home/node/.task-master \
  /home/node/.config/gh \
  /var/lib/tailscale \
  /home/node/go \
  /home/node/.cache/go-build \
  /var/spool/cron/crontabs \
  /home/node/projects

# Optional mounts may point to /dev/null (file placeholder). Avoid mkdir failures.
for opt_mount in /home/node/openclaw /home/node/workspace-1 /home/node/workspace-2 /home/node/workspace-3; do
  if [[ -e "${opt_mount}" && ! -d "${opt_mount}" ]]; then
    log "optional mount ${opt_mount} is a file placeholder, skipping directory init"
  else
    mkdir -p "${opt_mount}"
  fi
done

# Keep ownership fixes targeted to startup-critical paths.
for owned_dir in \
  /home/node/.ccman \
  /home/node/.claude \
  /home/node/.codex \
  /home/node/.gemini \
  /home/node/.config \
  /home/node/.openclaw \
  /home/node/.task-master \
  /home/node/go \
  /home/node/.cache \
  /var/spool/cron/crontabs; do
  if [[ -e "${owned_dir}" ]]; then
    chown -R node:node "${owned_dir}" || true
  fi
done

# Avoid recursively touching potentially large mounted workspaces.
for mount_root in /home/node/projects /home/node/openclaw /home/node/workspace-1 /home/node/workspace-2 /home/node/workspace-3; do
  if [[ -e "${mount_root}" ]]; then
    chown node:node "${mount_root}" || true
  fi
done

log "starting cron..."
safe_start_cron
maybe_start_tailscale
ensure_runtime_packages

CLAUDE_SETTINGS="/home/node/.claude/settings.json"
if [[ ! -f "${CLAUDE_SETTINGS}" ]] && [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  if [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
    cat >"${CLAUDE_SETTINGS}" <<EOF2
{
  "apiKey": "${ANTHROPIC_API_KEY}",
  "baseURL": "${ANTHROPIC_BASE_URL}"
}
EOF2
  else
    cat >"${CLAUDE_SETTINGS}" <<EOF2
{
  "apiKey": "${ANTHROPIC_API_KEY}"
}
EOF2
  fi
  chown node:node "${CLAUDE_SETTINGS}"
  log "generated: ${CLAUDE_SETTINGS}"
fi

CODEX_CONFIG="/home/node/.codex/config.toml"
if [[ ! -f "${CODEX_CONFIG}" ]] && [[ -n "${OPENAI_API_KEY:-}" ]]; then
  cat >"${CODEX_CONFIG}" <<EOF2
[auth]
api_key = "${OPENAI_API_KEY}"
EOF2
  if [[ -n "${OPENAI_BASE_URL:-}" ]]; then
    cat >>"${CODEX_CONFIG}" <<EOF2
base_url = "${OPENAI_BASE_URL}"
EOF2
  fi
  cat >>"${CODEX_CONFIG}" <<EOF2

[model]
default = "${CODEX_MODEL:-gpt-5-codex}"
wire_api = "responses"
EOF2
  chown node:node "${CODEX_CONFIG}"
  log "generated: ${CODEX_CONFIG}"
fi

GEMINI_CONFIG="/home/node/.config/gemini/config.json"
if [[ ! -f "${GEMINI_CONFIG}" ]] && [[ -n "${GEMINI_API_KEY:-}" ]]; then
  mkdir -p "$(dirname "${GEMINI_CONFIG}")"
  cat >"${GEMINI_CONFIG}" <<EOF2
{
  "apiKey": "${GEMINI_API_KEY}"
}
EOF2
  chown -R node:node /home/node/.config/gemini
  log "generated: ${GEMINI_CONFIG}"
fi

GEMINI_PROJECT_REGISTRY="/home/node/.gemini/projects.json"
if [[ ! -f "${GEMINI_PROJECT_REGISTRY}" ]]; then
  cat >"${GEMINI_PROJECT_REGISTRY}" <<EOF2
{
  "projects": {}
}
EOF2
  chown node:node "${GEMINI_PROJECT_REGISTRY}"
  log "seeded: ${GEMINI_PROJECT_REGISTRY}"
fi

TASKMASTER_ENV="/home/node/.task-master/global.env"
if [[ ! -f "${TASKMASTER_ENV}" ]]; then
  mkdir -p "$(dirname "${TASKMASTER_ENV}")"
  {
    [[ -n "${ANTHROPIC_API_KEY:-}" ]] && echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}"
    [[ -n "${OPENAI_API_KEY:-}" ]] && echo "OPENAI_API_KEY=${OPENAI_API_KEY}"
    [[ -n "${OPENROUTER_API_KEY:-}" ]] && echo "OPENROUTER_API_KEY=${OPENROUTER_API_KEY}"
    [[ -n "${PERPLEXITY_API_KEY:-}" ]] && echo "PERPLEXITY_API_KEY=${PERPLEXITY_API_KEY}"
    [[ -n "${OPENAI_BASE_URL:-}" ]] && echo "OPENAI_BASE_URL=${OPENAI_BASE_URL}"
    echo "TASKMASTER_MAIN_PROVIDER=${TASKMASTER_MAIN_PROVIDER:-anthropic}"
    echo "TASKMASTER_MAIN_MODEL=${TASKMASTER_MAIN_MODEL:-claude-sonnet-4-20250514}"
    [[ -n "${TASKMASTER_RESEARCH_PROVIDER:-}" ]] && echo "TASKMASTER_RESEARCH_PROVIDER=${TASKMASTER_RESEARCH_PROVIDER}"
    [[ -n "${TASKMASTER_RESEARCH_MODEL:-}" ]] && echo "TASKMASTER_RESEARCH_MODEL=${TASKMASTER_RESEARCH_MODEL}"
    [[ -n "${TASKMASTER_FALLBACK_PROVIDER:-}" ]] && echo "TASKMASTER_FALLBACK_PROVIDER=${TASKMASTER_FALLBACK_PROVIDER}"
    [[ -n "${TASKMASTER_FALLBACK_MODEL:-}" ]] && echo "TASKMASTER_FALLBACK_MODEL=${TASKMASTER_FALLBACK_MODEL}"
  } >"${TASKMASTER_ENV}"
  chown -R node:node /home/node/.task-master
  log "generated: ${TASKMASTER_ENV}"
fi

install_skills_and_extensions() {
  sync_repo_as_node "https://github.com/obra/superpowers" "/home/node/.superpowers" "superpowers"
  sync_repo_as_node "https://github.com/openclaw/skills" "/home/node/.openclaw-skills" "openclaw skills" 240

  if [[ ! -d "/home/node/.claude/skills/planning-with-files" ]]; then
    log "installing planning-with-files skill..."
    run_with_timeout_as_node 180 "npx -y skills add OthmanAdi/planning-with-files --all -y"
  fi

  if [[ ! -d "/home/node/.claude/skills/data-analyst" ]] && [[ -d "/home/node/.openclaw-skills/data-analyst" ]]; then
    log "installing data-analyst skill..."
    mkdir -p /home/node/.claude/skills /home/node/.codex/skills
    cp -r /home/node/.openclaw-skills/data-analyst /home/node/.claude/skills/
    cp -r /home/node/.openclaw-skills/data-analyst /home/node/.codex/skills/
    chown -R node:node /home/node/.claude/skills/data-analyst /home/node/.codex/skills/data-analyst
  fi

  if [[ ! -d "/home/node/.claude/skills/codex" ]]; then
    log "installing oil-oil/codex skill..."
    run_with_timeout_as_node 180 "npx -y skills add oil-oil/codex -a claude-code -y"
  fi

  if [[ ! -d "/home/node/.codex/extensions/ui-ux-pro-max" ]]; then
    log "installing ui-ux-pro-max for non-Claude tools..."
    run_with_timeout_as_node 45 "uipro init --ai codex --offline"
    run_with_timeout_as_node 45 "uipro init --ai gemini --offline"
    run_with_timeout_as_node 45 "uipro init --ai opencode --offline"
  fi
}

# Run skill/extension setup in the background so shell access is not blocked.
log "starting background skills/extensions setup..."
install_skills_and_extensions >/var/log/entrypoint-skills.log 2>&1 &

USER_INIT="${DATA_ROOT}/user-init.sh"
if [[ -f "${USER_INIT}" ]]; then
  log "running user-init.sh..."
  bash "${USER_INIT}"
fi

log "switching to node user..."
exec gosu node "$@"
