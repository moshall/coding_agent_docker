#!/usr/bin/env bash
# 在宿主机执行：确认 Claude Code 侧 superpowers 官方插件是否按预期安装。
# 用法:
#   ./scripts/verify-superpowers-claude-plugin.sh [容器名]
# 环境:
#   CONTAINER_NAME  默认 coding-agent
set -euo pipefail

CONTAINER_NAME="${1:-${CONTAINER_NAME:-coding-agent}}"

if ! docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "error: 容器不存在: $CONTAINER_NAME" >&2
  exit 2
fi

echo "=== 容器: $CONTAINER_NAME ==="

raw_enable="$(docker exec "$CONTAINER_NAME" sh -c 'printf %s "${SUPERPOWERS_CLAUDE_PLUGIN_ENABLE:-}"' || true)"
echo "SUPERPOWERS_CLAUDE_PLUGIN_ENABLE=${raw_enable:-<empty>}"
enable_lc="$(printf %s "$raw_enable" | tr '[:upper:]' '[:lower:]')"

skill_log() {
  docker exec "$CONTAINER_NAME" sh -c 'cat /var/log/entrypoint-skills.log 2>/dev/null || true'
}

echo ""
echo "=== entrypoint-skills.log 中 superpowers / claude 相关行 ==="
skill_log | grep -E "superpowers|SUPERPOWERS|claude plugin" || true

# 明确关闭时不做「必须已安装」判定
if [[ "$enable_lc" == "false" || "$enable_lc" == "0" || "$enable_lc" == "no" || "$enable_lc" == "off" ]]; then
  echo ""
  echo "ok: 当前为关闭态，跳过插件安装校验。"
  exit 0
fi

fail=0

if skill_log | grep -q "SUPERPOWERS_CLAUDE_PLUGIN_ENABLE disabled, skip claude plugin install"; then
  echo "" >&2
  echo "fail: 日志显示已跳过 Claude 插件，但环境变量并非 false/0/off（当前: '${raw_enable:-empty→compose 默认 true}）。请 exec 打印环境变量并确认 docker compose up 已载入 .env。" >&2
  fail=1
fi

if skill_log | grep -q "WARN: superpowers Claude plugin install failed"; then
  echo "" >&2
  echo "fail: 日志记载 Claude superpowers 插件安装失败。请查看完整 /var/log/entrypoint-skills.log" >&2
  fail=1
fi

if ! skill_log | grep -q "superpowers (Claude Code): claude plugin install"; then
  echo "" >&2
  echo "warn: 未找到安装命令日志行（容器若刚启动，可等待数分钟后重试）。" >&2
  fail=1
fi

echo ""
echo "=== claude plugin list（user node）==="
list_out=""
list_out="$(docker exec --user node -e NODE_ENV=production "$CONTAINER_NAME" bash -lc \
  'command -v claude >/dev/null 2>&1 && claude plugin list 2>&1 || echo __NO_CLAUDE__' || true)"
printf '%s\n' "$list_out"

if printf '%s' "$list_out" | grep -q "__NO_CLAUDE__"; then
  echo "" >&2
  echo "fail: 容器内未找到 claude 命令" >&2
  fail=1
elif printf '%s' "$list_out" | grep -qi superpowers; then
  echo ""
  echo "ok: plugin list 中含 superpowers（与开启态一致）。"
else
  if [[ "$fail" -eq 0 ]]; then
    echo "" >&2
    echo "warn: plugin list 未匹配 superpowers，请对照上游文档核对名称或稍后再试。" >&2
    fail=1
  fi
fi

exit "$fail"
