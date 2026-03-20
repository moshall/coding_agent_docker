#!/usr/bin/env bash

set -euo pipefail

if [[ "$(id -u)" != "0" ]]; then
  echo "[entrypoint] ERROR: must run as root" >&2
  exit 1
fi

DATA_ROOT="${DATA_ROOT:-/data/coding-agent}"
BOOTSTRAP_ROOT="${DATA_ROOT}/software/bootstrap"
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

# Host layout (single ${DATA_ROOT} mount):
#   project/   — 工作区（容器内 ~/project，并兼容 ~/projects -> ~/project）
#   config/    — 各工具配置子目录（claude、codedex、…）
#   software/  — 运行时与缓存（tailscale、go、cron、go-build-cache、bootstrap）
ensure_ln_home() {
  local link_path="$1"
  local data_path="$2"

  mkdir -p "${data_path}"

  if [[ -L "${link_path}" ]]; then
    local cur
    cur="$(readlink -f "${link_path}" 2>/dev/null || true)"
    if [[ "${cur}" == "$(readlink -f "${data_path}" 2>/dev/null || echo "${data_path}")" ]]; then
      return
    fi
    rm -f "${link_path}"
  elif [[ -d "${link_path}" ]]; then
    if [[ -z "$(ls -A "${link_path}" 2>/dev/null)" ]]; then
      rmdir "${link_path}" 2>/dev/null || true
    else
      log "WARN: ${link_path} is non-empty; not replacing with symlink -> ${data_path}"
      return
    fi
  elif [[ -e "${link_path}" ]]; then
    log "WARN: ${link_path} exists; skip symlink -> ${data_path}"
    return
  fi

  ln -sfn "${data_path}" "${link_path}"
}

# 1Panel / 习惯把卷放在 root 家目录下时，镜像内 /root 常为 0700，uid 1000 的 node 无法进入子路径。
# 将 /root 设为 0711：其它用户可进入已知子路径，但不能列举 /root 下内容（常见加固做法）。
ensure_data_root_traversable_for_node() {
  if [[ "${DATA_ROOT:-}" != /root/* ]]; then
    return
  fi
  if [[ ! -d /root ]]; then
    return
  fi
  log "DATA_ROOT under /root: chmod 0711 /root (1Panel / root-home layout; node must traverse)"
  if ! chmod 0711 /root; then
    log "WARN: chmod 0711 /root failed — move DATA_ROOT outside /root or fix permissions on the host"
  fi
}

link_persistence_from_data_root() {
  log "DATA_ROOT layout: ${DATA_ROOT}/{project,config,software}/ ..."

  if [[ -d "${DATA_ROOT}/config/bootstrap" ]] && [[ ! -d "${DATA_ROOT}/software/bootstrap" ]]; then
    mkdir -p "${DATA_ROOT}/software/bootstrap"
    shopt -s nullglob
    for f in "${DATA_ROOT}/config/bootstrap"/*; do
      [[ -e "${f}" ]] || continue
      mv "${f}" "${DATA_ROOT}/software/bootstrap/" 2>/dev/null || true
    done
    shopt -u nullglob
    rmdir "${DATA_ROOT}/config/bootstrap" 2>/dev/null || true
  fi

  mkdir -p \
    "${DATA_ROOT}/project" \
    "${DATA_ROOT}/config/claude" \
    "${DATA_ROOT}/config/codex" \
    "${DATA_ROOT}/config/superpowers" \
    "${DATA_ROOT}/config/ccman" \
    "${DATA_ROOT}/config/gemini" \
    "${DATA_ROOT}/config/gemini-home" \
    "${DATA_ROOT}/config/opencode" \
    "${DATA_ROOT}/config/taskmaster" \
    "${DATA_ROOT}/config/gh" \
    "${DATA_ROOT}/config/agents" \
    "${DATA_ROOT}/software/tailscale" \
    "${DATA_ROOT}/software/go" \
    "${DATA_ROOT}/software/go-build-cache" \
    "${DATA_ROOT}/software/cron/crontabs" \
    "${DATA_ROOT}/software/bootstrap"

  if [[ -d "${DATA_ROOT}/projects" && ! -e "${DATA_ROOT}/project" ]]; then
    log "legacy: ${DATA_ROOT}/project -> projects"
    ln -sfn "${DATA_ROOT}/projects" "${DATA_ROOT}/project"
  fi

  ensure_ln_home "/home/node/.claude" "${DATA_ROOT}/config/claude"
  ensure_ln_home "/home/node/.codex" "${DATA_ROOT}/config/codex"
  ensure_ln_home "/home/node/.superpowers" "${DATA_ROOT}/config/superpowers"
  ensure_ln_home "/home/node/.ccman" "${DATA_ROOT}/config/ccman"
  mkdir -p /home/node/.config
  ensure_ln_home "/home/node/.config/gemini" "${DATA_ROOT}/config/gemini"
  ensure_ln_home "/home/node/.gemini" "${DATA_ROOT}/config/gemini-home"
  ensure_ln_home "/home/node/.config/opencode" "${DATA_ROOT}/config/opencode"
  ensure_ln_home "/home/node/.task-master" "${DATA_ROOT}/config/taskmaster"
  ensure_ln_home "/home/node/.config/gh" "${DATA_ROOT}/config/gh"
  ensure_ln_home "/home/node/.agents" "${DATA_ROOT}/config/agents"

  ensure_ln_home "/home/node/go" "${DATA_ROOT}/software/go"
  mkdir -p /home/node/.cache
  ensure_ln_home "/home/node/.cache/go-build" "${DATA_ROOT}/software/go-build-cache"

  ensure_ln_home "/var/lib/tailscale" "${DATA_ROOT}/software/tailscale"
  ensure_ln_home "/var/spool/cron/crontabs" "${DATA_ROOT}/software/cron/crontabs"

  ensure_ln_home "/home/node/project" "${DATA_ROOT}/project"
  ensure_ln_home "/home/node/projects" "/home/node/project"

}

maybe_start_cloudcli() {
  if ! is_truthy "${CLOUDCLI_ENABLE:-true}"; then
    log "CloudCLI disabled (CLOUDCLI_ENABLE), skipping"
    return
  fi
  if ! command -v cloudcli >/dev/null 2>&1; then
    log "cloudcli not found, skipping"
    return
  fi

  # CloudCLI uses Node fs.mkdir on ~/.config/cloudcli; a symlink there can yield EACCES (Node 22).
  # Use only real directories under ${DATA_ROOT}/software/cloudcli-xdg.
  local cli_xdg="${DATA_ROOT}/software/cloudcli-xdg"
  local cli_state="${cli_xdg}/cloudcli"
  mkdir -p "${cli_xdg}" "${cli_state}"

  if [[ -d "${DATA_ROOT}/config/cloudcli" ]] && [[ -n "$(ls -A "${DATA_ROOT}/config/cloudcli" 2>/dev/null)" ]]; then
    if [[ ! -f "${cli_state}/auth.db" ]] && [[ -z "$(ls -A "${cli_state}" 2>/dev/null)" ]]; then
      log "migrating CloudCLI: ${DATA_ROOT}/config/cloudcli -> ${cli_state}"
      cp -a "${DATA_ROOT}/config/cloudcli/." "${cli_state}/" 2>/dev/null || true
    fi
  fi

  chown -R node:node "${cli_xdg}"

  local port="${CLOUDCLI_PORT:-3001}"
  log "starting CloudCLI (claudecodeui) on 0.0.0.0:${port} (log: /var/log/cloudcli.log)..."
  nohup gosu node env \
    HOME=/home/node \
    USER=node \
    LOGNAME=node \
    XDG_CONFIG_HOME="${cli_xdg}" \
    NODE_ENV="${NODE_ENV:-production}" \
    SERVER_PORT="${port}" \
    HOST=0.0.0.0 \
    DATABASE_PATH="${cli_state}/auth.db" \
    cloudcli >>/var/log/cloudcli.log 2>&1 &
  sleep 1
}

ensure_data_root_traversable_for_node
link_persistence_from_data_root

mkdir -p /home/node/.agents/skills

# Own persisted trees (follows symlinks into ${DATA_ROOT})
for owned_dir in \
  /home/node/.ccman \
  /home/node/.claude \
  /home/node/.codex \
  /home/node/.superpowers \
  /home/node/.agents \
  /home/node/.gemini \
  /home/node/.config \
  /home/node/.task-master \
  /home/node/project \
  /home/node/go \
  /home/node/.cache \
  /var/spool/cron/crontabs; do
  if [[ -e "${owned_dir}" ]]; then
    chown -R node:node "${owned_dir}" || true
  fi
done

if [[ -e /home/node/projects ]]; then
  chown -h node:node /home/node/projects 2>/dev/null || true
fi

# ~/.claude、~/.ccman 等指向 ${DATA_ROOT}/config/* 时，chown -R 符号链接默认不作用到绑定挂载目标，node 会 EACCES
if [[ -n "${DATA_ROOT:-}" ]]; then
  chown -R node:node "${DATA_ROOT}/config" "${DATA_ROOT}/project" 2>/dev/null || true
fi

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

maybe_start_cloudcli

# Superpowers — Codex: https://github.com/obra/superpowers/blob/main/.codex/INSTALL.md
install_superpowers_for_codex() {
  local root="/home/node/.superpowers"
  if [[ ! -d "${root}/skills" ]]; then
    log "superpowers ${root}/skills missing, skip Codex install layout"
    return
  fi

  log "superpowers (Codex): ln -s ${root} ~/.codex/superpowers && ln -s .../skills ~/.agents/skills/superpowers"
  ln -sfn "${root}" /home/node/.codex/superpowers
  mkdir -p /home/node/.agents/skills
  ln -sfn /home/node/.codex/superpowers/skills /home/node/.agents/skills/superpowers
  chown -h node:node /home/node/.codex/superpowers /home/node/.agents/skills/superpowers 2>/dev/null || true
}

# Superpowers — Claude Code: https://github.com/obra/superpowers#claude-code-official-marketplace
install_superpowers_for_claude() {
  if ! is_truthy "${SUPERPOWERS_CLAUDE_PLUGIN_ENABLE:-true}"; then
    log "SUPERPOWERS_CLAUDE_PLUGIN_ENABLE disabled, skip claude plugin install"
    return
  fi
  if ! command -v claude >/dev/null 2>&1; then
    log "claude CLI not found, skip superpowers plugin install"
    return
  fi

  # 上游 README：官方 market 可能尚未收录时，需先注册 obra/superpowers-marketplace 再装 superpowers@superpowers-marketplace
  log "superpowers (Claude Code): marketplace add obra/superpowers-marketplace; install superpowers@superpowers-marketplace (fallback @claude-plugins-official)"
  run_with_timeout_as_node 360 "claude plugin marketplace add obra/superpowers-marketplace || true; claude plugin install superpowers@superpowers-marketplace --scope user || claude plugin install superpowers@claude-plugins-official --scope user"
  log "superpowers (Claude Code): plugin install step finished (see log above for marketplace/CLI errors)"
}

install_skills_and_extensions() {
  sync_repo_as_node "https://github.com/obra/superpowers" "/home/node/.superpowers" "superpowers"

  install_superpowers_for_codex
  install_superpowers_for_claude

  if [[ ! -d "/home/node/.claude/skills/planning-with-files" ]]; then
    log "installing planning-with-files skill..."
    run_with_timeout_as_node 180 "npx -y skills add OthmanAdi/planning-with-files --all -y"
  fi

  if [[ ! -d "/home/node/.claude/skills/codex" ]]; then
    log "installing oil-oil/codex skill..."
    run_with_timeout_as_node 180 "npx -y skills add oil-oil/codex -a claude-code -y"
  fi

  if [[ ! -d "/home/node/.codex/extensions/ui-ux-pro-max" ]]; then
    log "installing ui-ux-pro-max for Codex..."
    run_with_timeout_as_node 45 "uipro init --ai codex --offline"
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
