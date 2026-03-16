# PRD：Coding Agent Docker 发行版

**文档版本**：v1.4  
**状态**：Draft  
**作者**：Gardama  
**创建日期**：2026-03-13  
**最后更新**：2026-03-13  
**变更说明**：全面重写。三层目录心智模型、标准 Compose bind mount（移除 --privileged/C2 方案）、user-init.sh 用户软件持久化钩子、MOUNT_OPENCLAW 命名挂载

---

## 1. 背景与动机

将 Coding Agent 工具集从 OpenClaw 容器中完整拆分，构建独立的、可发行的 Docker 镜像。

**核心设计原则**：
- 小白三句话能明白数据在哪、安不安全
- 重建容器不丢任何东西（授权、配置、项目、自定义软件）
- 开箱即用，`.env` 填完直接启动，不需要懂 Docker

---

## 2. 三层目录心智模型

这是整个持久化设计的核心，用户只需记住三句话：

```
┌─────────────────────────────────────────────────────────────┐
│  第一层：/data/coding-agent/                                 │
│  "容器的大脑，授权和配置都在这，别动，重建不会丢"              │
│  → 自动挂载，用户无需操作                                     │
├─────────────────────────────────────────────────────────────┤
│  第二层：项目目录                                             │
│  "我的代码在这，放心写，重建也不会丢"                          │
│  → 默认 /data/coding-agent/projects/，容器内 ~/projects/     │
├─────────────────────────────────────────────────────────────┤
│  第三层：可选的额外目录                                        │
│  "想把别的东西带进来，比如 OpenClaw 目录，.env 填一行"         │
│  → MOUNT_OPENCLAW、MOUNT_EXTRA_1/2/3，空着就不挂             │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. 工具清单

**Base Image**：`node:22-bookworm`  
**运行用户**：`node`（uid=1000）  
**注意**：Claude Code 明确拒绝以 root 运行，entrypoint 以 root 完成初始化后通过 `gosu` 切换至 node 用户

### 3.1 Coding Agent CLI

| 工具 | 安装方式 |
|------|----------|
| Claude Code CLI | npm global `@anthropic-ai/claude-code` |
| Codex CLI | npm global `@openai/codex` |
| Gemini CLI | npm global `@google/gemini-cli` |
| OpenCode | npm global `opencode-ai` |
| Task Master | npm global `task-master-ai` |
| Ralph Orchestrator | npm global（GitHub 源） |
| ccman | npm global `ccman` |
| cc-connect | Go multi-stage 编译 |
| gh（GitHub CLI） | apt 官方源 |

### 3.2 连接与会话管理

| 工具 | 安装方式 | 说明 |
|------|----------|------|
| tmux | apt `tmux` | 终端复用，保持长会话，防止 exec 断开后任务中断 |
| tailscale | apt 官方源 | 零配置 VPN，内嵌二进制；需 `NET_ADMIN` + tun 设备 |
| gosu | apt `gosu` | entrypoint root→node 用户切换，信号传递正确 |

### 3.3 开发环境预装

| 运行时/工具 | 来源 | 说明 |
|------------|------|------|
| Node.js 22 + npm + npx | base image 自带 | |
| Python 3 + pip | apt `python3 python3-pip` | |
| uv | pip 安装 | 快速 Python 包管理器 |
| Go | apt `golang` | cc-connect 编译 + 用户可用 |
| Rust + Cargo | rustup 非交互（node 用户） | 装到 `~/.cargo/`，bind mount 持久化 |
| cron | apt `cron` | 定时任务守护进程，entrypoint 后台启动 |

### 3.4 辅助工具

| 工具 | 安装方式 | 说明 |
|------|----------|------|
| uipro-cli | npm global `uipro-cli` | ui-ux-pro-max skill 安装器 |

---

## 4. 持久化设计

### 4.1 宿主机目录结构（第一层：全自动）

```
/data/coding-agent/                       ← DATA_ROOT（.env 可改，默认此值）
│
├── config/                               ← 工具授权与配置（最重要，别动）
│   ├── claude/        → ~/.claude        ← Claude Code auth、settings、plugins、skills
│   ├── codex/         → ~/.codex         ← Codex config.toml、skills
│   ├── gemini/        → ~/.config/gemini ← Gemini auth
│   ├── opencode/      → ~/.config/opencode
│   ├── taskmaster/    → ~/.task-master
│   ├── gh/            → ~/.config/gh     ← GitHub CLI token
│   ├── tailscale/     → /var/lib/tailscale
│   └── cargo/         → ~/.cargo         ← Rust toolchain（避免每次重建重装）
│
├── cron/
│   └── crontabs/      → /var/spool/cron/crontabs
│
├── projects/          → ~/projects       ← 第二层：默认项目目录
│
└── user-init.sh       ← 用户自定义初始化钩子（可选，见第 6 章）
```

### 4.2 docker-compose.yml volumes 配置

```yaml
services:
  coding-agent:
    volumes:
      # ── 第一层：工具配置（全自动，用户无需关心）──────────────────────────────
      - ${DATA_ROOT:-/data/coding-agent}/config/claude:/home/node/.claude
      - ${DATA_ROOT:-/data/coding-agent}/config/codex:/home/node/.codex
      - ${DATA_ROOT:-/data/coding-agent}/config/gemini:/home/node/.config/gemini
      - ${DATA_ROOT:-/data/coding-agent}/config/opencode:/home/node/.config/opencode
      - ${DATA_ROOT:-/data/coding-agent}/config/taskmaster:/home/node/.task-master
      - ${DATA_ROOT:-/data/coding-agent}/config/gh:/home/node/.config/gh
      - ${DATA_ROOT:-/data/coding-agent}/config/tailscale:/var/lib/tailscale
      - ${DATA_ROOT:-/data/coding-agent}/config/cargo:/home/node/.cargo
      - ${DATA_ROOT:-/data/coding-agent}/cron/crontabs:/var/spool/cron/crontabs
      # ── 第二层：项目目录 ─────────────────────────────────────────────────────
      - ${DATA_ROOT:-/data/coding-agent}/projects:/home/node/projects
      # ── 第三层：可选额外挂载（.env 填路径，空着不挂）────────────────────────
      - ${MOUNT_OPENCLAW:-/dev/null}:/home/node/openclaw
      - ${MOUNT_EXTRA_1:-/dev/null}:/home/node/workspace-1
      - ${MOUNT_EXTRA_2:-/dev/null}:/home/node/workspace-2
      - ${MOUNT_EXTRA_3:-/dev/null}:/home/node/workspace-3
    cap_add:
      - NET_ADMIN       # Tailscale 需要
    devices:
      - /dev/net/tun:/dev/net/tun
```

### 4.3 第三层：可选额外挂载

用户在 `.env` 中填写宿主机路径，留空则使用 `/dev/null` 作为占位符（无害，不影响启动）：

```env
# 把 OpenClaw 的数据目录挂进来
# 当 OpenClaw 容器挂掉时，可以在这个容器里直接访问和修复
MOUNT_OPENCLAW=/data/openclaw

# 其他需要带进来的目录（不需要就留空）
MOUNT_EXTRA_1=
MOUNT_EXTRA_2=
MOUNT_EXTRA_3=
```

容器内对应路径：

| 变量 | 容器内路径 | 典型用途 |
|------|-----------|----------|
| `MOUNT_OPENCLAW` | `~/openclaw/` | 访问和修复 OpenClaw 配置 |
| `MOUNT_EXTRA_1` | `~/workspace-1/` | 其他项目、共享代码库 |
| `MOUNT_EXTRA_2` | `~/workspace-2/` | NAS 数据集、共享资源 |
| `MOUNT_EXTRA_3` | `~/workspace-3/` | 备用 |

**超出 3 个额外挂载**：直接在 `docker-compose.yml` 的 volumes 段添加一行即可，格式相同。实际使用中 3 个通常足够。

### 4.4 重建与升级保障

```
数据在宿主机 /data/coding-agent/ ──→ 与容器生命周期完全解耦
        ↓
重建镜像 = 更新工具二进制版本
        ↓
entrypoint 幂等检测：
  配置文件已存在 → 跳过写入（auth token 完整保留）
  skill 已安装   → 跳过安装
  user-init.sh 存在 → 重新执行（重装用户软件）
```

| 场景 | 结果 |
|------|------|
| `docker compose restart` | 数据完整，毫秒级恢复 |
| `docker compose down && up` | 数据完整，重新 attach volumes |
| 镜像重建（`--build`） | 工具版本更新，数据不丢，CLI 立即可用 |
| 拉取新镜像版本 | 同上 |

---

## 5. entrypoint.sh 设计

entrypoint 以 **root** 启动，完成所有初始化后通过 `gosu node` 切换至普通用户运行主进程。

### 5.1 执行流程

```
entrypoint.sh（root）
    │
    ├─ 1. 创建所有挂载目标目录（mkdir -p），修正归属（chown node:node）
    │
    ├─ 2. 启动后台服务
    │      ├─ cron &
    │      └─ tailscaled --state=... &（若 TAILSCALE_AUTHKEY 有值则 tailscale up）
    │
    ├─ 3. 生成工具配置文件（幂等：文件已存在则跳过）
    │      ├─ ~/.claude/settings.json
    │      ├─ ~/.codex/config.toml
    │      ├─ ~/.task-master/global.env
    │      └─ ~/.config/gemini/config.json
    │
    ├─ 4. 安装 Skills（幂等：目录已存在则跳过）
    │      ├─ planning-with-files（npx skills add --all -y）
    │      ├─ data-analyst（cp from build-time clone）
    │      ├─ oil-oil/codex（npx skills add -a claude-code -y）
    │      └─ ui-ux-pro-max 非 Claude 端（uipro init --offline）
    │
    ├─ 5. 执行 user-init.sh（若存在）
    │
    └─ 6. exec gosu node "$@"（切换用户，替换当前进程）
```

### 5.2 关键代码片段

**目录初始化**：
```bash
mkdir -p \
  /home/node/.claude \
  /home/node/.codex \
  /home/node/.config/gemini \
  /home/node/.config/opencode \
  /home/node/.task-master \
  /home/node/.config/gh \
  /home/node/projects \
  /home/node/.cargo
chown -R node:node /home/node/
```

**配置文件生成（幂等示例）**：
```bash
CLAUDE_SETTINGS="/home/node/.claude/settings.json"
if [ ! -f "${CLAUDE_SETTINGS}" ] && [ -n "${ANTHROPIC_API_KEY}" ]; then
  cat > "${CLAUDE_SETTINGS}" <<EOF
{
  "apiKey": "${ANTHROPIC_API_KEY}"
  $([ -n "${ANTHROPIC_BASE_URL}" ] && echo ", \"baseURL\": \"${ANTHROPIC_BASE_URL}\"")
}
EOF
  echo "[entrypoint] generated: ${CLAUDE_SETTINGS}"
fi
```

**user-init.sh 钩子**：
```bash
USER_INIT="${DATA_ROOT:-/data/coding-agent}/user-init.sh"
if [ -f "${USER_INIT}" ]; then
  echo "[entrypoint] running user-init.sh..."
  bash "${USER_INIT}"
fi
```

**切换用户**：
```bash
exec gosu node "$@"
```

---

## 6. user-init.sh：用户软件持久化

### 6.1 设计理念

**容器负责通用工具**（所有人都需要的），**用户负责个性化软件**（只有你需要的）。

`user-init.sh` 是一个钩子文件，放在持久化目录里，容器每次启动时自动执行。用户写一次，重建容器自动重装，不需要再手动操作。

### 6.2 使用方式

```bash
# 宿主机上，复制示例文件
cp /data/coding-agent/user-init.sh.example /data/coding-agent/user-init.sh

# 编辑，填入自己想要的软件
vim /data/coding-agent/user-init.sh
```

### 6.3 user-init.sh.example（随镜像预置）

```bash
#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# user-init.sh — 用户自定义初始化脚本
#
# 用途：在这里安装你个人需要的软件。
#       容器每次启动都会执行这个文件，重建后自动恢复。
#
# 使用方法：
#   cp /data/coding-agent/user-init.sh.example \
#      /data/coding-agent/user-init.sh
#   然后编辑这个文件，取消注释你需要的部分。
#
# 注意：这里已经是 root 权限，无需 sudo。
# ═══════════════════════════════════════════════════════════════

# ── 系统工具 ──────────────────────────────────────────────────
# apt-get install -y -q vim tree htop jq

# ── Node.js 全局包 ────────────────────────────────────────────
# npm install -g typescript ts-node eslint prettier

# ── Python 包 ─────────────────────────────────────────────────
# pip3 install jupyterlab notebook --break-system-packages

# ── Rust 工具 ─────────────────────────────────────────────────
# su - node -c "cargo install ripgrep bat"

# ── 自定义 shell 配置 ─────────────────────────────────────────
# cat >> /home/node/.bashrc << 'EOF'
# alias ll='ls -alF'
# export EDITOR=vim
# EOF

echo "[user-init] done."
```

### 6.4 执行时机与权限

| 属性 | 说明 |
|------|------|
| 执行时机 | 每次容器启动（`entrypoint.sh` step 5） |
| 执行权限 | root（可以 apt install，可以 su - node） |
| 幂等性 | 用户自己保证（示例里 apt install 天然幂等） |
| 文件位置 | `/data/coding-agent/user-init.sh`（持久化目录内） |
| 不存在时 | 跳过，正常启动 |

---

## 7. API Key 与工具配置

### 7.1 配置分层

```
.env             → API Key、路径、端口（用户填写，不提交 git）
docker-compose   → Volume 结构、权限（不含 Key）
entrypoint.sh    → 根据 ENV 生成各工具 config（幂等）
工具 config 文件  → 工具行为参数（模型、协议等）
```

### 7.2 各工具配置

**Claude Code** — `~/.claude/settings.json`

| ENV | 必填 | 说明 |
|-----|------|------|
| `ANTHROPIC_API_KEY` | ✅ | |
| `ANTHROPIC_BASE_URL` | ❌ | 中转代理地址 |

**Codex** — `~/.codex/config.toml`

`wire_api` 仅支持 `responses`（OpenAI Responses API），Chat Completions 已 deprecated，使用第三方中转需确认对端支持。

| ENV | 必填 | 说明 |
|-----|------|------|
| `OPENAI_API_KEY` | ✅ | |
| `OPENAI_BASE_URL` | ❌ | 需支持 Responses API |
| `CODEX_MODEL` | ❌ | 默认 `gpt-5-codex` |

**Gemini** — `~/.config/gemini/config.json`

| ENV | 必填 |
|-----|------|
| `GEMINI_API_KEY` | ✅ |

**Task Master** — `~/.task-master/global.env`

支持 main/research/fallback 三角色，每角色可用不同 provider：

| ENV | 必填 | 说明 |
|-----|------|------|
| `ANTHROPIC_API_KEY` | 条件 | anthropic provider |
| `OPENAI_API_KEY` | 条件 | openai provider |
| `OPENROUTER_API_KEY` | 条件 | 推荐，统一中转多模型 |
| `PERPLEXITY_API_KEY` | ❌ | research model 推荐 |
| `OPENAI_BASE_URL` | ❌ | 覆盖 openai base URL |
| `TASKMASTER_MAIN_PROVIDER` | ❌ | 默认 `anthropic` |
| `TASKMASTER_MAIN_MODEL` | ❌ | 默认 `claude-sonnet-4-20250514` |
| `TASKMASTER_RESEARCH_PROVIDER` | ❌ | |
| `TASKMASTER_RESEARCH_MODEL` | ❌ | |
| `TASKMASTER_FALLBACK_PROVIDER` | ❌ | |
| `TASKMASTER_FALLBACK_MODEL` | ❌ | |

**GitHub CLI**

| ENV | 必填 | 说明 |
|-----|------|------|
| `GH_TOKEN` | ❌ | 预授权，也可进容器 `gh auth login` |

---

## 8. Tailscale

内嵌模式，apt 预装二进制，state 持久化到 `/data/coding-agent/config/tailscale/`。

**docker-compose.yml**：
```yaml
cap_add:
  - NET_ADMIN
devices:
  - /dev/net/tun:/dev/net/tun
```

**entrypoint.sh 启动逻辑**：
```bash
tailscaled --state=/var/lib/tailscale/tailscaled.state &
if [ -n "${TAILSCALE_AUTHKEY}" ]; then
  sleep 2
  tailscale up \
    --authkey="${TAILSCALE_AUTHKEY}" \
    --hostname="${TAILSCALE_HOSTNAME:-coding-agent}"
fi
```

**手动操作**：
```bash
docker compose exec coding-agent tailscale up      # 首次接入
docker compose exec coding-agent tailscale status  # 查看状态
```

**重建后行为**：state 文件持久化，通常无需重新 `tailscale up`。

| ENV | 必填 | 说明 |
|-----|------|------|
| `TAILSCALE_AUTHKEY` | ❌ | 有值时 entrypoint 自动接入 |
| `TAILSCALE_HOSTNAME` | ❌ | 默认 `coding-agent` |

---

## 9. tmux

apt 预装，无需配置。核心用途：防止 `docker exec` 断开后 agent 任务中断。

```bash
docker compose exec coding-agent bash
tmux new -s main          # 创建会话
claude                    # 启动 agent
# Ctrl+B d               # 脱离（会话保持后台运行）
docker compose exec coding-agent tmux attach -t main  # 重新接入
```

---

## 10. Skills 体系

### 10.1 安装层级

#### 🟢 Build-time（Dockerfile，完全自动）

| 内容 | 操作 |
|------|------|
| data-analyst pip 依赖 | `pip3 install pandas matplotlib seaborn scipy --break-system-packages` |
| uipro-cli | `npm install -g uipro-cli` |
| superpowers repo | `git clone --depth 1 https://github.com/obra/superpowers /home/node/.superpowers` |
| openclaw skills repo | `git clone https://github.com/openclaw/skills /home/node/.openclaw-skills` |

#### 🟡 Entrypoint（首次启动，幂等，自动）

| Skill | 安装命令 | 生效范围 |
|-------|----------|----------|
| planning-with-files | `npx skills add OthmanAdi/planning-with-files --all -y` | Claude Code / Codex / Gemini / OpenCode |
| data-analyst | cp from `~/.openclaw-skills/` | Claude Code / Codex |
| oil-oil/codex | `npx skills add oil-oil/codex -a claude-code -y` | Claude Code 专属 |
| ui-ux-pro-max（非 Claude 端） | `uipro init --ai codex --offline && uipro init --ai gemini --offline` | Codex / Gemini / OpenCode |

#### 🔴 手动一次（进容器执行，volume 持久化后永久有效）

| Skill | 工具 | 安装命令 |
|-------|------|----------|
| superpowers | Claude Code | `/plugin marketplace add obra/superpowers-marketplace` → `/plugin install superpowers@superpowers-marketplace` |
| superpowers | Codex | session 内告知 agent fetch `.codex/INSTALL.md` |
| superpowers | OpenCode | session 内告知 agent fetch `.opencode/INSTALL.md` |
| superpowers | Gemini | `gemini extensions install https://github.com/obra/superpowers` |
| qiaomu-design-advisor | Claude Code | 确认 marketplace 名称后 `/plugin install` |
| ui-ux-pro-max | Claude Code | `/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill` → `/plugin install ui-ux-pro-max@ui-ux-pro-max-skill` |

---

## 11. .env 完整模板

```env
# ╔══════════════════════════════════════════════════════════════════╗
# ║              Coding Agent — 环境配置文件                         ║
# ║  复制此文件为 .env，填入你的配置，启动即可                         ║
# ║  此文件包含敏感信息，不要提交到 git                               ║
# ╚══════════════════════════════════════════════════════════════════╝

# ── 路径 ──────────────────────────────────────────────────────────────────────
# 所有持久化数据的宿主机根目录（修改后需重建容器）
DATA_ROOT=/data/coding-agent

# ── 容器基础 ──────────────────────────────────────────────────────────────────
CONTAINER_NAME=coding-agent
TZ=Asia/Shanghai
NODE_ENV=development

# ── Claude Code ───────────────────────────────────────────────────────────────
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxx
# ANTHROPIC_BASE_URL=https://your-proxy.example.com

# ── Codex ─────────────────────────────────────────────────────────────────────
OPENAI_API_KEY=sk-xxxxxxxxxx
# OPENAI_BASE_URL=https://your-proxy.example.com/v1   # 需支持 Responses API
# CODEX_MODEL=gpt-5-codex

# ── Gemini CLI ────────────────────────────────────────────────────────────────
GEMINI_API_KEY=AIzaxxxxxxxxxx

# ── Task Master ───────────────────────────────────────────────────────────────
# OPENROUTER_API_KEY=sk-or-xxxxxxxxxx    # 推荐：可统一中转多个模型
# PERPLEXITY_API_KEY=pplx-xxxxxxxxxx     # research model 推荐
TASKMASTER_MAIN_PROVIDER=anthropic
TASKMASTER_MAIN_MODEL=claude-sonnet-4-20250514
# TASKMASTER_RESEARCH_PROVIDER=perplexity
# TASKMASTER_RESEARCH_MODEL=sonar-pro
# TASKMASTER_FALLBACK_PROVIDER=anthropic
# TASKMASTER_FALLBACK_MODEL=claude-haiku-4-5-20251001

# ── GitHub CLI ────────────────────────────────────────────────────────────────
# GH_TOKEN=ghp_xxxxxxxxxx

# ── Tailscale ─────────────────────────────────────────────────────────────────
# TAILSCALE_AUTHKEY=tskey-auth-xxxxxxxxxx
# TAILSCALE_HOSTNAME=coding-agent

# ── 端口映射 ──────────────────────────────────────────────────────────────────
PORT_CC_CONNECT=8080
PORT_RALPH=3000
PORT_DEV=9000

# ── 第三层：可选额外挂载 ──────────────────────────────────────────────────────
# 填入宿主机上的目录路径即可，留空则不挂载
#
# 示例：把 OpenClaw 目录挂进来
# 当 OpenClaw 挂掉时，可以在这个容器里直接访问它的文件、排查和修复
# MOUNT_OPENCLAW=/data/openclaw
MOUNT_OPENCLAW=

# 其他需要带进来的目录（任意用途）
# MOUNT_EXTRA_1=/home/user/my-other-project
# MOUNT_EXTRA_2=/mnt/nas/datasets
# MOUNT_EXTRA_3=
MOUNT_EXTRA_1=
MOUNT_EXTRA_2=
MOUNT_EXTRA_3=
```

---

## 12. 文件结构

```
coding-agent/
├── Dockerfile                  # multi-stage build（Go builder + node:22-bookworm）
├── docker-compose.yml          # 发行版（image 字段）
├── docker-compose.dev.yml      # 开发版（本地 build context）
├── entrypoint.sh               # 启动初始化（root 执行，gosu 切换）
├── user-init.sh.example        # 用户软件钩子示例文件
├── .env.example                # 环境变量模板（即第 11 章内容）
├── .gitignore                  # 排除 .env
└── README.md
```

---

## 13. README 结构（面向小白）

README 应覆盖以下内容，语言平实：

1. **这是什么** — 一句话
2. **三层目录** — 复述第 2 章的三句话，附目录结构图
3. **快速开始** — 5 步：clone → cp .env.example .env → 填 API Key → docker compose up -d → 进容器用 claude
4. **挂载 OpenClaw 目录** — 单独一节，填 `MOUNT_OPENCLAW=` 那一行，重启生效
5. **让我的软件重建后还在** — 单独一节，编辑 `user-init.sh` 的步骤
6. **手动安装 Skills** — 列出🔴红色部分，一次操作即永久
7. **常见问题** — 授权失效怎么办、怎么彻底重置、crontab 怎么用

---

## 14. 回归校验

### TC-BUILD：构建

**TC-BUILD-01：无缓存构建成功**
```bash
docker compose -f docker-compose.dev.yml build --no-cache
# 预期：无 ERROR
```

**TC-BUILD-02：Go 工具链不在最终镜像**
```bash
docker history coding-agent:latest | grep -i golang
# 预期：无输出
```

**TC-BUILD-03：Python 依赖预装**
```bash
docker run --rm coding-agent:latest python3 -c \
  "import pandas, matplotlib, seaborn, scipy; print('OK')"
# 预期：OK
```

**TC-BUILD-04：全部开发环境工具可用**
```bash
docker run --rm coding-agent:latest bash -c "
  python3 --version && pip3 --version && uv --version &&
  go version && rustup --version && cargo --version &&
  node --version && npm --version && tmux -V && tailscale --version"
# 预期：全部输出版本号
```

---

### TC-USER：用户身份

**TC-USER-01：主进程以 node 运行**
```bash
docker compose exec coding-agent whoami
# 预期：node
```

**TC-USER-02：Claude Code 拒绝 root**
```bash
docker compose exec -u root coding-agent claude --version 2>&1
# 预期：包含 root 限制错误
```

---

### TC-TOOL：CLI 可用性

```bash
docker compose exec coding-agent bash -c "
  claude --version && codex --version && gemini --version &&
  opencode --version && task-master --version &&
  ralph --version && ccman --help &&
  cc-connect --version && gh --version"
# 预期：全部正常输出
```

---

### TC-PERSIST：持久化

**TC-PERSIST-01：宿主机目录自动创建**
```bash
docker compose up -d
ls /data/coding-agent/config/
# 预期：claude  codex  gemini  opencode  taskmaster  gh  tailscale  cargo
```

**TC-PERSIST-02：重建后数据保留，CLI 立即可用**
```bash
docker compose exec coding-agent bash -c \
  'echo "rebuild-test" > /home/node/.claude/rebuild-test.txt'

# 无缓存重建
docker compose down
docker compose -f docker-compose.dev.yml build --no-cache
docker compose up -d

# 数据仍在
cat /data/coding-agent/config/claude/rebuild-test.txt
# 预期：rebuild-test

# CLI 立即可用
docker compose exec coding-agent claude --version
# 预期：输出版本号，无报错
```

**TC-PERSIST-03：gh auth 重建后保留**
```bash
# 容器内完成 gh auth login 后
docker compose down && docker compose up -d
docker compose exec coding-agent gh auth status
# 预期：已认证，无需重新登录
```

**TC-PERSIST-04：Rust toolchain 重建后保留**
```bash
docker compose exec coding-agent cargo --version
docker compose down && docker compose up -d
docker compose exec coding-agent cargo --version
# 预期：版本一致，无需重装
```

**TC-PERSIST-05：项目目录双向读写**
```bash
echo "from-host" > /data/coding-agent/projects/test.txt
docker compose exec coding-agent cat /home/node/projects/test.txt
# 预期：from-host

docker compose exec coding-agent bash -c \
  'echo "from-container" > /home/node/projects/c.txt'
cat /data/coding-agent/projects/c.txt
# 预期：from-container
```

---

### TC-MOUNT：可选额外挂载

**TC-MOUNT-01：MOUNT_OPENCLAW 生效**
```bash
mkdir -p /data/openclaw && echo "openclaw-data" > /data/openclaw/test.txt
# .env: MOUNT_OPENCLAW=/data/openclaw
docker compose up -d
docker compose exec coding-agent cat /home/node/openclaw/test.txt
# 预期：openclaw-data
```

**TC-MOUNT-02：留空不影响启动**
```bash
# .env: MOUNT_OPENCLAW=（留空）
docker compose ps
# 预期：running，无报错
```

**TC-MOUNT-03：MOUNT_EXTRA_1/2/3 并行生效**
```bash
mkdir -p /tmp/extra1 /tmp/extra2
# .env: MOUNT_EXTRA_1=/tmp/extra1  MOUNT_EXTRA_2=/tmp/extra2  MOUNT_EXTRA_3=（空）
docker compose up -d
docker compose exec coding-agent ls /home/node/workspace-1 /home/node/workspace-2
# 预期：正常列出，workspace-3 对应 /dev/null 不可访问但不报错
```

---

### TC-USERINIT：用户初始化钩子

**TC-USERINIT-01：user-init.sh 自动执行**
```bash
cat > /data/coding-agent/user-init.sh << 'EOF'
#!/bin/bash
touch /tmp/user-init-ran
EOF
docker compose restart coding-agent
docker compose exec coding-agent ls /tmp/user-init-ran
# 预期：文件存在
```

**TC-USERINIT-02：不存在时跳过不报错**
```bash
rm -f /data/coding-agent/user-init.sh
docker compose restart coding-agent
docker compose ps | grep coding-agent
# 预期：running
```

**TC-USERINIT-03：安装用户软件后重建恢复**
```bash
cat > /data/coding-agent/user-init.sh << 'EOF'
#!/bin/bash
apt-get install -y -q vim
EOF

docker compose down
docker compose -f docker-compose.dev.yml build --no-cache
docker compose up -d

docker compose exec coding-agent which vim
# 预期：/usr/bin/vim
```

---

### TC-ENV：配置写入（幂等）

**TC-ENV-01：首次启动自动生成配置文件**
```bash
docker compose up -d
ls /data/coding-agent/config/claude/settings.json
ls /data/coding-agent/config/codex/config.toml
ls /data/coding-agent/config/taskmaster/global.env
# 预期：文件均存在
```

**TC-ENV-02：幂等——已有配置不被覆盖**
```bash
echo "# idempotent-test" >> /data/coding-agent/config/claude/settings.json
docker compose restart coding-agent
tail -1 /data/coding-agent/config/claude/settings.json
# 预期：# idempotent-test
```

**TC-ENV-03：Codex wire_api 协议正确**
```bash
grep wire_api /data/coding-agent/config/codex/config.toml
# 预期：wire_api = "responses"
```

---

### TC-CRON：定时任务

**TC-CRON-01：守护进程运行**
```bash
docker compose exec coding-agent pgrep cron
# 预期：有 PID 输出
```

**TC-CRON-02：crontab 持久化**
```bash
docker compose exec coding-agent bash -c \
  'echo "0 * * * * echo hello" | crontab -'
docker compose down && docker compose up -d
docker compose exec coding-agent crontab -l
# 预期：crontab 仍存在
```

---

### TC-TMUX：会话管理

**TC-TMUX-01：tmux 可用**
```bash
docker compose exec coding-agent tmux -V
# 预期：tmux 3.x
```

**TC-TMUX-02：会话在 exec 断开后保持**
```bash
docker compose exec coding-agent tmux new -d -s test "sleep 600"
docker compose exec coding-agent tmux ls
# 预期：test 会话仍在运行
```

---

### TC-TAILSCALE：网络连接

**TC-TAILSCALE-01：二进制可用**
```bash
docker compose exec coding-agent tailscale --version
# 预期：输出版本号
```

**TC-TAILSCALE-02：AUTHKEY 自动连接**
```bash
# .env 中 TAILSCALE_AUTHKEY 已填写
docker compose up -d && sleep 10
docker compose exec coding-agent tailscale status
# 预期：Connected 状态
```

**TC-TAILSCALE-03：state 重建后保留**
```bash
docker compose down && docker compose up -d
docker compose exec coding-agent tailscale status
# 预期：Connected，无需重新 tailscale up
```

---

### TC-SKILLS：Skill 安装

**TC-SKILLS-01：planning-with-files 多端自动安装**
```bash
ls /data/coding-agent/config/claude/skills/planning-with-files/SKILL.md
ls /data/coding-agent/config/codex/skills/planning-with-files/SKILL.md
# 预期：文件存在
```

**TC-SKILLS-02：data-analyst + Python 依赖**
```bash
ls /data/coding-agent/config/claude/skills/data-analyst/SKILL.md
docker compose exec coding-agent python3 -c "import pandas; print('ok')"
# 预期：skill 存在，依赖可用
```

**TC-SKILLS-03：oil-oil/codex skill**
```bash
ls /data/coding-agent/config/claude/skills/codex/SKILL.md
# 预期：存在
```

**TC-SKILLS-04：skill 重建后保留（幂等）**
```bash
docker compose down
docker compose -f docker-compose.dev.yml build --no-cache
docker compose up -d
ls /data/coding-agent/config/claude/skills/
# 预期：skills 目录完整，entrypoint 幂等跳过重装
```

---

### TC-PORT：端口映射

**TC-PORT-01：默认端口**
```bash
docker compose ps
# 预期：8080->8080, 3000->3000, 9000->9000
```

**TC-PORT-02：自定义端口**
```bash
# .env: PORT_CC_CONNECT=18080
docker compose ps
# 预期：18080->8080
```

---

### TC-RELEASE：发行版

**TC-RELEASE-01：从 Registry 冷启动**
```bash
mkdir test-release && cd test-release
# 仅放 docker-compose.yml + .env
docker compose up -d
# 重复 TC-TOOL、TC-BUILD-03、TC-BUILD-04
```

**TC-RELEASE-02：热启动时间**
```bash
time docker compose up -d
# 预期：< 5s（数据在 /data/，entrypoint 幂等快速跳过）
```

---

## 15. 已知限制与风险

| 风险 | 说明 | 缓解措施 |
|------|------|----------|
| Tailscale NET_ADMIN | 部分 PaaS/VPS 不允许该 capability | 文档说明；不需要时注释 cap_add |
| Codex Responses API | 中转代理需支持该协议 | 文档明确注明，提供测试命令 |
| Rust 初次 build 耗时 | rustup 下载 ~500MB | `config/cargo/` bind mount 复用 |
| user-init.sh 无幂等保证 | 用户自己写，可能重复安装 | 示例文件中说明；`apt install` 天然幂等 |
| 手动 skill 无法自动化 | Claude Code Plugin Marketplace 交互式 | 一次手动，bind mount 永久保留 |
| data-analyst openclaw repo | 需确认 repo 公开可访问 | 验证后按需 fork |
| /dev/null 占位符 | 极少数 Docker 版本可能有兼容性问题 | 测试覆盖；出问题改为空目录占位 |

---

## 16. CI/CD：GitHub Actions 自动构建与推送

### 16.1 目标

push 到 main 或打版本 tag 时，自动构建 amd64 + arm64 双架构镜像并推送到 Docker Hub，用户无需手动 build，始终能拉到最新镜像。

### 16.2 触发策略

| 触发方式 | 场景 | 镜像标签 |
|----------|------|----------|
| push 到 `main` 分支 | 日常开发提交，持续集成 | `latest`、`main-<short-sha>` |
| 打 tag `v*.*.*` | 正式发版 | `v1.5.0`、`1.5`、`1`、`latest` |

> PR 合并不单独触发，合并到 main 后由 push 事件自动覆盖。  
> 不设手动触发——需要热修复时直接 push 到 main 即可。

### 16.3 构建架构

同时构建 `linux/amd64`（服务器主流）和 `linux/arm64`（Mac M 芯片、树莓派），通过 Docker Buildx + QEMU 模拟，单 workflow 输出 multi-arch manifest，用户 `docker pull` 自动匹配架构。

### 16.4 GitHub Secrets 配置

仓库 → Settings → Secrets and variables → Actions，添加两个：

| Secret 名 | 说明 |
|-----------|------|
| `DOCKERHUB_USERNAME` | Docker Hub 用户名 |
| `DOCKERHUB_TOKEN` | Docker Hub Access Token（在 Docker Hub → Account Settings → Security → New Access Token 生成，**不要用密码**） |

### 16.5 Workflow 文件

路径：`.github/workflows/build-push.yml`

```yaml
name: Build & Push Multi-Arch Image

on:
  push:
    branches:
      - main
    tags:
      - 'v*.*.*'

env:
  IMAGE: ${{ secrets.DOCKERHUB_USERNAME }}/coding-agent

jobs:
  build-push:
    runs-on: ubuntu-latest
    steps:
      # ── 1. 检出代码 ────────────────────────────────────────────────────────
      - name: Checkout
        uses: actions/checkout@v4

      # ── 2. 计算镜像标签 ────────────────────────────────────────────────────
      - name: Docker meta
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.IMAGE }}
          tags: |
            # push to main → latest + main-<sha>
            type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' }}
            type=sha,prefix=main-,enable=${{ github.ref == 'refs/heads/main' }}
            # tag v1.2.3 → v1.2.3 + 1.2 + 1 + latest
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}
            type=raw,value=latest,enable=${{ startsWith(github.ref, 'refs/tags/v') }}

      # ── 3. 设置 QEMU（arm64 模拟） ─────────────────────────────────────────
      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      # ── 4. 设置 Buildx ─────────────────────────────────────────────────────
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      # ── 5. 登录 Docker Hub ─────────────────────────────────────────────────
      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      # ── 6. 构建 + 推送（amd64 + arm64）────────────────────────────────────
      - name: Build and push
        id: build-push
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      # ── 7. 输出摘要 ────────────────────────────────────────────────────────
      - name: Summary
        run: |
          echo "### 构建完成 ✅" >> $GITHUB_STEP_SUMMARY
          echo "**镜像**：\`${{ env.IMAGE }}\`" >> $GITHUB_STEP_SUMMARY
          echo "**标签**：${{ steps.meta.outputs.tags }}" >> $GITHUB_STEP_SUMMARY
          echo "**摘要**：\`${{ steps.build-push.outputs.digest }}\`" >> $GITHUB_STEP_SUMMARY
```

### 16.6 标签规则说明

```
push main    →  your-username/coding-agent:latest
              your-username/coding-agent:main-a1b2c3d

push v1.5.0  →  your-username/coding-agent:v1.5.0
              your-username/coding-agent:1.5
              your-username/coding-agent:1
              your-username/coding-agent:latest
```

> 打 tag 时 `latest` 会被覆盖为正式版本。建议发版流程：先测试 main 的 `latest`，确认没问题再打 tag 固化版本。

### 16.7 构建耗时预估

| 阶段 | 首次（无缓存） | 后续（有 GHA 缓存） |
|------|--------------|-------------------|
| amd64 构建 | ~15 min（含 Rust） | ~5 min |
| arm64 构建（QEMU 模拟） | ~40 min | ~15 min |
| 推送到 Docker Hub | ~2 min | ~2 min |
| **合计** | **~57 min** | **~22 min** |

> Rust toolchain（~500MB）是最耗时的层，`type=gha` 缓存在同一仓库的后续构建中命中率很高。  
> 如果后期 arm64 构建时间不可接受，可升级为 GitHub 付费的 native arm64 runner，构建速度提升 5-10 倍。

### 16.8 文件结构补充

```
coding-agent/
├── .github/
│   └── workflows/
│       └── build-push.yml    # ← 新增
├── Dockerfile
├── docker-compose.yml
└── ...
```

### 16.9 用户拉取方式

```bash
# 拉取最新版
docker pull your-username/coding-agent:latest

# 拉取指定版本（推荐，避免 latest 飘移）
docker pull your-username/coding-agent:v1.5.0
```

`docker-compose.yml` image 字段：

```yaml
services:
  coding-agent:
    image: your-username/coding-agent:latest
    # 或锁定版本：
    # image: your-username/coding-agent:v1.5.0
```

---

## 17. 版本计划

| 版本 | 内容 |
|------|------|
| v1.0 | 核心工具 + 基础持久化 |
| v1.1 | 多客户端协议配置、多目录挂载 |
| v1.2 | 开发环境、cron、完整 Skills 体系 |
| v1.3 | Bind Mount 到 /data/、tmux/tailscale |
| **v1.4（本版）** | 三层目录心智模型、标准挂载、user-init.sh 钩子、MOUNT_OPENCLAW 命名挂载、CI/CD 设计 |
| v1.5 | 实施 CI/CD（GitHub Actions 双 Registry + 双架构） |
| v2.0 | MCP Server 管理集成 |
