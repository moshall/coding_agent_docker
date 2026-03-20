# coding_agent_docker

[![Build](https://github.com/moshall/coding_agent_docker/actions/workflows/build-push.yml/badge.svg)](https://github.com/moshall/coding_agent_docker/actions/workflows/build-push.yml)
[![Release](https://img.shields.io/github/v/release/moshall/coding_agent_docker?sort=semver)](https://github.com/moshall/coding_agent_docker/releases)
[![License](https://img.shields.io/github/license/moshall/coding_agent_docker)](./LICENSE)

一个面向远程开发、VPS 常驻、1Panel 部署和团队统一环境的 AI Coding Agent Docker 镜像。
它把常用 AI CLI、数据分析工具、配置持久化和启动自举流程整合到一个可直接运行的容器里，并通过 GHCR + GitHub Actions 持续构建发布。

- 公开镜像：`ghcr.io/moshall/coding_agent_docker`
- 推荐标签：`latest`、`vX.Y.Z`、`sha-<commit>`、`date-YYYYMMDD`
- 自动构建时间：每日北京时间 `07:00`
- 默认运行形态：通用 CLI 工作容器，不强绑定单一 Web 服务
- 项目状态：持续维护，支持 GHCR 公共拉取、每日自动构建与版本标签发布

## Table of Contents

- [Why This Image](#why-this-image)
- [Use Cases](#use-cases)
- [What Is Included](#what-is-included)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Persistence Model](#persistence-model)
- [Deployment Examples](#deployment-examples)
- [Common Operations](#common-operations)
- [Build and Release](#build-and-release)
- [Troubleshooting](#troubleshooting)
- [Related Docs](#related-docs)
- [Support](#support)
- [License](#license)

## Why This Image

这个项目对齐 GitHub README 的常见写法：先回答“它是什么、适合谁、如何上手”，再展开配置、持久化、运维和发布细节。

它的核心目标是：

- 用一个镜像统一 Claude Code、Codex、Gemini CLI、Task Master、OpenCode 等工具的运行环境。
- 让配置、授权和项目目录持久化，避免容器重建后从头再配。
- 兼容 VPS、原生 Docker、1Panel、GitHub Actions 等常见使用方式。
- 把“可拉取、可启动、可进入、可配置、可回归”的链路做成稳定的发布流程。

## Use Cases

适合以下场景：

- 个人在 Linux 主机或云服务器上搭建长期可复用的 AI 开发工作台。
- 团队共享同一套 CLI 和初始化逻辑，降低环境漂移。
- 在 1Panel 或类似面板中快速部署一个长期运行的 Coding Agent 容器。
- 作为基础镜像或开发底座，为后续项目脚本、自动化任务或编排系统提供统一环境。

## What Is Included

### Preinstalled Tools

| 类别 | 内容 | 说明 |
| --- | --- | --- |
| AI CLI | `claude-code`、`codex`、`task-master` | 镜像内预装；`gemini-cli` / `opencode-ai` 未预装以控制体积，可按需 `npm i -g` |
| Web UI | [CloudCLI](https://github.com/siteboon/claudecodeui)（`cloudcli` / `@siteboon/claude-code-ui`） | 默认监听 `0.0.0.0:3001`，与现有 `~/.claude` 会话/配置同源；许可为 **GPL-3.0**（见上游仓库） |
| 配置工具 | `ccman` | 已做包装，自动以 `node` 用户 + `NODE_ENV=production` 运行 |
| 连接/桥接 | `cc-connect` | 构建阶段编译真实二进制，并在 CI 中校验 |
| 开发运维 | `git`、`gh`、`tmux`、`cron`、`curl`、`wget` | 便于长期驻留和日常操作 |
| Python 工具链 | `python3`、`pip`、`uv`、`pandas`、`matplotlib`、`seaborn`、`scipy` | 适合数据处理与脚本任务 |
| 网络 | `tailscale`、`tailscaled` | 可选启用，需要 `NET_ADMIN` 和 `/dev/net/tun` |

### Runtime Bootstrap

容器启动时会自动做这些事：

- 初始化配置目录与权限。
- 启动 `cron`。
- 启动 `tailscaled`，有 `TAILSCALE_AUTHKEY` 时自动执行 `tailscale up`。
- 根据环境变量生成 Claude、Codex、Gemini、Task Master 的基础配置。
- 为 Gemini 预置项目注册表，避免首次运行时的 registry 报错。
- 按需安装 `golang` 和 `build-essential`，并把这个选择持久化。
- 默认启动 **CloudCLI**（可用 `CLOUDCLI_ENABLE=false` 关闭），便于浏览器远程使用 Claude Code / Codex 等会话。
- 后台安装 skills/extensions，不阻塞主终端。
- 如存在 `${DATA_ROOT}/user-init.sh`，则在启动时执行。
- 最终把主进程切换为 `node` 用户。

### Bundled Skills and Extensions

镜像会按幂等方式初始化以下内容（详见 [obra/superpowers](https://github.com/obra/superpowers)）：

- **Superpowers — Claude Code**：默认开启，首次后台执行 `claude plugin marketplace add obra/superpowers-marketplace` 后安装 `superpowers@superpowers-marketplace`（失败时再尝试 `superpowers@claude-plugins-official`，与 [obra/superpowers README](https://github.com/obra/superpowers#claude-code-official-marketplace) 一致）。可用 `SUPERPOWERS_CLAUDE_PLUGIN_ENABLE=false` 关闭；需出网。
- **Superpowers — Codex**：与官方 [.codex/INSTALL.md](https://github.com/obra/superpowers/blob/main/.codex/INSTALL.md) 一致——`~/.superpowers` 的克隆同步 **`ln -s` → `~/.codex/superpowers`**，再 **`~/.agents/skills/superpowers` → .../skills**（Codex 通过 `~/.agents/skills` 发现 skill）。
- `planning-with-files`、`oil-oil/codex`、`uipro init --ai codex --offline`（Codex 端 ui-ux-pro-max）。

说明：后台日志 `/var/log/entrypoint-skills.log`。镜像**不再**克隆 `openclaw/skills` 等第三方 skill 归档；需要额外 skill 请在容器内自行 `npx skills add ...` 或挂载自带目录。

## Quick Start

### 1. Clone and Configure

```bash
git clone https://github.com/moshall/coding_agent_docker.git
cd coding_agent_docker
cp .env.example .env
```

然后按需填写 `.env` 中的密钥。

最小可用示例：

```env
ANTHROPIC_API_KEY=your_anthropic_key
OPENAI_API_KEY=your_openai_key
# 可选
GEMINI_API_KEY=your_gemini_key
```

说明：

- 当前实现里，没有“必须填写才能启动容器”的硬性环境变量。
- 但你要使用哪个产品，就需要填写对应的 API Key。
- 不使用的功能可以留空，容器仍可启动。

### 2. Start the Container

```bash
docker compose up -d
```

### 3. Enter the Container

推荐直接以 `node` 用户进入，并加上 **`-it`**（交互式 + 伪终端），便于 TUI、颜色与 `bash` 行编辑：

```bash
docker exec -it --user node -e NODE_ENV=production coding-agent bash
```

若在项目目录使用 Compose，等价写法：

```bash
docker compose exec -it --user node -e NODE_ENV=production coding-agent bash
```

### 4. Smoke Check

```bash
claude --version
codex --version
task-master --version
ccman --version
# 若自行全局安装：gemini --version / opencode --version
cloudcli version
# 浏览器访问（宿主机映射默认 3001）：http://<主机>:3001
```

### 5. 升级镜像（尽量无感）

数据在 `DATA_ROOT`，更换镜像版本一般不丢配置。发布新版本后在本机编排目录执行：

```bash
docker compose pull && docker compose up -d
```

可选：`docker compose up -d --force-recreate` 强制用新 entrypoint 启容器。若自行 Pin 了 `DOCKER_IMAGE=...:sha-xxx`，请同步改为新 digest 或 `latest`。

## Configuration

完整变量清单见 [.env.example](./.env.example)。

### Required vs Optional

| 类型 | 变量 | 说明 |
| --- | --- | --- |
| 启动有默认值 | `DATA_ROOT`、`CONTAINER_NAME`、`TZ`、`NODE_ENV`、`PORT_*`、`DOCKER_IMAGE` | 留空会回落到默认值 |
| 按功能必填 | `ANTHROPIC_API_KEY`、`OPENAI_API_KEY`、`GEMINI_API_KEY`、`OPENROUTER_API_KEY`、`PERPLEXITY_API_KEY` | 只有使用对应产品或 provider 时才需要 |
| 可选代理/网关 | `ANTHROPIC_BASE_URL`、`OPENAI_BASE_URL` | 使用代理或兼容网关时填写 |
| Task Master 可选项 | `TASKMASTER_MAIN_PROVIDER`、`TASKMASTER_MAIN_MODEL`、`TASKMASTER_RESEARCH_*`、`TASKMASTER_FALLBACK_*` | 默认主模型已设置为 Claude Sonnet |
| 可选系统能力 | `GH_TOKEN`、`TAILSCALE_AUTHKEY`、`TAILSCALE_HOSTNAME` | 不影响基础启动 |
| CloudCLI | `CLOUDCLI_ENABLE`（默认启用）、`CLOUDCLI_PORT`（容器内端口，默认 `3001`）、`PORT_CLOUDCLI`（Compose 映射） | Web UI；设为 `CLOUDCLI_ENABLE=false` 可跳过开机自启 |
| Superpowers | `SUPERPOWERS_CLAUDE_PLUGIN_ENABLE`（默认 `true`） | Claude 侧：先注册 **`obra/superpowers-marketplace`** 再装 **`superpowers@superpowers-marketplace`**（失败再尝试 `claude-plugins-official`）；需出网；`false` 可跳过。Codex 侧由 entrypoint 按上游 `INSTALL.md` 建链 |
| 可选运行时增强 | `INSTALL_GO_RUNTIME`、`INSTALL_BUILD_ESSENTIAL` | 留空表示关闭，设为 `true` 表示启动时安装，并将选择持久化 |
| 用户自定义挂载 | 自行编辑 `docker-compose.yml` 的 `volumes` | 例如与宿主机其它项目目录同路径挂载，镜像不提供 OpenClaw 专用变量 |

### Optional Runtime Package Switches

这两个变量是“开关型变量”，不是必填项：

- `GOPATH`、`GOCACHE` 只是目录位置定义，建议保留，不会因为存在就自动安装 Go。
- `INSTALL_GO_RUNTIME=` 和 `INSTALL_BUILD_ESSENTIAL=` 留空时，表示关闭。
- `INSTALL_GO_RUNTIME=true` 或 `INSTALL_BUILD_ESSENTIAL=true` 时，表示在容器启动时安装对应运行时包。

需要特别注意的是，这两个开关带“持久化记忆”：

- 一旦开启过，启动脚本会写入 `${DATA_ROOT}/software/bootstrap/install-go-runtime`
- 或 `${DATA_ROOT}/software/bootstrap/install-build-essential`

之后即使你把环境变量改回留空，容器仍可能继续安装，因为 marker 文件还在。

如果你想彻底关闭，做两件事：

- 把对应环境变量改回留空
- 删除对应的 marker 文件

### Default Model Settings

当前默认值来自 [docker-compose.yml](./docker-compose.yml)：

- `CODEX_MODEL=gpt-5-codex`
- `TASKMASTER_MAIN_PROVIDER=anthropic`
- `TASKMASTER_MAIN_MODEL=claude-sonnet-4-20250514`

## Persistence Model

这个镜像不是“每次重建都从零开始”的一次性容器，而是带明确持久化设计的工作容器。

**Compose 里只需要挂一条数据根目录**（默认 `${DATA_ROOT:-/data/coding-agent}` 对应到容器内同一路径）。`entrypoint.sh` 在启动时把 `~/.claude`、`~/.codex`、`~/project` 等链接到该根下的子目录，无需为每个工具单独写 `volumes`。

### 三层目录（心智模型）

| 目录 | 作用 |
| --- | --- |
| `${DATA_ROOT}/project/` | 默认代码与工作区；容器内 `/home/node/project`。若你过去用了 `projects/`，首次启动会自动做兼容（`project` → `projects`） |
| `${DATA_ROOT}/config/` | 各工具配置与状态（`.claude`、`.codex`、Task Master、CloudCLI、`~/.agents` 等，由脚本链入 `$HOME`） |
| `${DATA_ROOT}/software/` | 运行时数据：Tailscale 状态、`GOPATH`、`go-build` 缓存、cron、`software/bootstrap` 安装标记等 |

其它约定：

- `${DATA_ROOT}/user-init.sh` 若存在会在启动时执行。
- 需要与**其它栈**共享某宿主机路径（例如自建 agent 的工作区）时，在 `docker-compose.yml` 里**自行**增加 `volumes` 即可；镜像不再提供 `MOUNT_OPENCLAW` 等专用变量。

**绑定挂载与权限**：`~/.claude`、`~/.agents` 等指向 `${DATA_ROOT}/config/...`。若在宿主机上预先创建了这些目录且属主为 **root**，早期镜像可能出现 **`EACCES`（无法创建 `~/.claude/plugins`、skills 安装失败）**。当前 `entrypoint` 会在启动时对 `${DATA_ROOT}/config/claude`、`codex`、`agents`、`superpowers` 及 **`project`** 执行 **`chown -R node:node`**（容器内 uid **1000**）。若你仍在使用旧镜像，可在宿主机执行一次 `chown -R 1000:1000 <DATA_ROOT>/config ...` 后重启容器，或 **`docker compose pull && docker compose up -d --force-recreate`** 拉到新构建。

### 挂载前如何设权限（宿主机）

绑定卷是**把宿主机目录挂进容器**，进程在容器里多是以 **`node`（uid 1000）** 读写，因此应**先在宿主机**做好目录与属主，再 `docker compose up`：

1. **创建数据根目录**（与 compose / `.env` 里 `DATA_ROOT` 一致）：
   ```bash
   sudo mkdir -p /你的/DATA_ROOT路径
   ```
2. **把目录交给容器内的 node（推荐用数字 uid，避免宿主机没有 `node` 用户）**：
   ```bash
   sudo chown -R 1000:1000 /你的/DATA_ROOT路径
   ```
   若有**额外挂载**（例如 OpenClaw 与 `project/openclaw` 对齐），对**宿主机上那一侧路径**同样执行 `chown -R 1000:1000`。
3. **再启动编排**：`docker compose up -d`（或在 1Panel 中创建/启动）。

说明：镜像 `entrypoint` 里对 **`${DATA_ROOT}/config/*`** 等的 **`chown`** 作用在容器内看到的挂载点上，一般与在宿主机先 `chown 1000:1000` 一致；**若宿主机顽固为 root 且挂载已就绪**，仍以你在宿主机上的属主为准——故**先赋权再挂**最稳。

### 1Panel / `DATA_ROOT` 在宿主机 `/root/...` 下

面板有时把数据放在 **root 家目录**下。要点：

- **宿主机**上 **`/root` 常见权限 0700**（仅 root 可进）。容器内 **`uid 1000` 无法穿过 `/root` 到达** `/root/apps/...` 之类的挂载点，会出现 **Permission denied**——这与镜像内是否执行 `chmod` **无关**，因为 **绑定挂载用的是宿主机文件系统的权限**。
- **推荐**：把 `DATA_ROOT` 设到 **`/opt/...`、`/data/...`**（如 [deploy/1panel](./deploy/1panel/docker-compose.yml) 默认），按上一小节 **`mkdir` + `chown -R 1000:1000`** 后再挂。
- **若必须放在宿主机 `/root/...`**（尽量不推荐）：
  1. 仍对**数据目录本身**执行：`sudo chown -R 1000:1000 /root/你的数据路径`；
  2. 并保证 **uid 1000 能沿路径进入**：通常需在**宿主机**对 `/root` 做一次（与常见加固一致）：`sudo chmod 0711 /root` —— 他人**不能列举** `/root` 下有什么，但**可进入已知的子路径**（请按你的安全策略评估后再操作）。

**容器内**若 `DATA_ROOT` 以 `/root/` 开头，镜像仍会对**容器内** `/root` 做 **`chmod 0711`** 以兼容「数据在容器 root 家目录」的非挂载布局；**纯 bind mount 时以宿主机权限为主**，请按上面宿主机步骤处理。

<details>
<summary>展开：config / software 下常见子路径（自动创建，一般不必手改）</summary>

- `config/claude`、`config/codex`、`config/superpowers`、`config/ccman`、`config/gemini`、`config/gemini-home`、`config/opencode`、`config/taskmaster`、`config/gh`、`config/agents`
- `software/tailscale`、`software/go`、`software/go-build-cache`、`software/cron/crontabs`、`software/bootstrap`、`software/cloudcli-xdg`（CloudCLI 状态与 DB，避免 `~/.config/cloudcli` 符号链接触发 Node `mkdir` 报错）

</details>

## Deployment Examples

### 1Panel 编排模板

1Panel **没有**单独的「应用商店 JSON 模板」，实际就是在指定目录放置 **`docker-compose.yml` + `.env`**，由面板调用 Docker Compose。

本仓库提供一份 **面向 1Panel 的现成编排**（与根目录 `docker-compose.yml` 行为一致，但按面板常见坑做了适配）：

| 文件 | 说明 |
|------|------|
| [deploy/1panel/docker-compose.yml](./deploy/1panel/docker-compose.yml) | 推荐使用。**`image` 为纯字符串**（面板预拉镜像不认 `${DOCKER_IMAGE}`）；**`container_name`、主数据卷、`ports` 为字面量**，避免变量未替换；默认数据目录 **`/opt/1panel/apps/coding_agent_docker`**；顶栏 **`name:`** 为 Compose 项目名；**不写 `version:`**，避免 Compose V2 提示 obsolete。 |
| [deploy/1panel/.env.example](./deploy/1panel/.env.example) | 复制为同目录 `.env`，填写 API Key 等。 |
| [deploy/1panel/README.md](./deploy/1panel/README.md) | 目录示例、OpenClaw 附加卷、`invalid reference format` 说明。 |

**推荐操作顺序**：

```text
1. 宿主机：sudo mkdir -p /opt/1panel/apps/coding_agent_docker && sudo chown -R 1000:1000 /opt/1panel/apps/coding_agent_docker
2. 将 deploy/1panel/docker-compose.yml、.env（由 .env.example 复制）放到同一目录，例如 /opt/1panel/docker/compose/coding-agent/
3. 面板：容器 → Compose/编排 → 选择该目录创建
4. 安全组放行 Web 端口（默认映射 3001 为 CloudCLI 等，见 yml 中 ports）
```

若需改数据路径或映射端口，请**直接编辑** `deploy/1panel/docker-compose.yml` 中对应行（仅改 `.env` 不会自动改 `volumes` / `ports` 字面量）。面板报错排障另见本文 **Troubleshooting** 中的 「1Panel（或类似面板）…」 小节。

### Compose Template

下面内容与仓库根目录 [**docker-compose.yml**](./docker-compose.yml) **保持同一套编排**（维护时以仓库文件为唯一事实来源；此处方便「复制即用」）。

**你需要自己提供的主要是密钥**：在同级目录创建 `.env`，至少填写要用的 `ANTHROPIC_API_KEY`、`OPENAI_API_KEY` 等（见 [.env.example](./.env.example)）。**其余项在下列模板里已全部列出**：带 `:-默认值` 或 `:-`（空默认）的变量可不写 `.env`；密钥行使用 `${VAR:-}`，未设置时不再触发 Compose 的 “variable is not set” 告警（部分面板会把该告警 stderr 误判为失败）。

```yaml
services:
  coding-agent:
    image: ${DOCKER_IMAGE:-ghcr.io/moshall/coding_agent_docker:latest}
    container_name: ${CONTAINER_NAME:-coding-agent}
    restart: unless-stopped

    environment:
      - TZ=${TZ:-Asia/Shanghai}
      - NODE_ENV=${NODE_ENV:-development}
      - DATA_ROOT=${DATA_ROOT:-/data/coding-agent}
      - GOPATH=/home/node/go
      - GOCACHE=/home/node/.cache/go-build
      - INSTALL_GO_RUNTIME=${INSTALL_GO_RUNTIME:-}
      - INSTALL_BUILD_ESSENTIAL=${INSTALL_BUILD_ESSENTIAL:-}

      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
      - ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL:-}

      - OPENAI_API_KEY=${OPENAI_API_KEY:-}
      - OPENAI_BASE_URL=${OPENAI_BASE_URL:-}
      - CODEX_MODEL=${CODEX_MODEL:-gpt-5-codex}

      - GEMINI_API_KEY=${GEMINI_API_KEY:-}

      - OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}
      - PERPLEXITY_API_KEY=${PERPLEXITY_API_KEY:-}
      - TASKMASTER_MAIN_PROVIDER=${TASKMASTER_MAIN_PROVIDER:-anthropic}
      - TASKMASTER_MAIN_MODEL=${TASKMASTER_MAIN_MODEL:-claude-sonnet-4-20250514}
      - TASKMASTER_RESEARCH_PROVIDER=${TASKMASTER_RESEARCH_PROVIDER:-}
      - TASKMASTER_RESEARCH_MODEL=${TASKMASTER_RESEARCH_MODEL:-}
      - TASKMASTER_FALLBACK_PROVIDER=${TASKMASTER_FALLBACK_PROVIDER:-}
      - TASKMASTER_FALLBACK_MODEL=${TASKMASTER_FALLBACK_MODEL:-}

      - GH_TOKEN=${GH_TOKEN:-}

      - TAILSCALE_AUTHKEY=${TAILSCALE_AUTHKEY:-}
      - TAILSCALE_HOSTNAME=${TAILSCALE_HOSTNAME:-coding-agent}

      - CLOUDCLI_ENABLE=${CLOUDCLI_ENABLE:-true}
      - CLOUDCLI_PORT=${CLOUDCLI_PORT:-3001}

      - SUPERPOWERS_CLAUDE_PLUGIN_ENABLE=${SUPERPOWERS_CLAUDE_PLUGIN_ENABLE:-true}

    volumes:
      # 仅挂载数据根目录；entrypoint 将 ~/.claude / .codex 等链到 ${DATA_ROOT}/config/* ，见 README
      - ${DATA_ROOT:-/data/coding-agent}:${DATA_ROOT:-/data/coding-agent}

    ports:
      - "${PORT_CC_CONNECT:-8080}:8080"
      - "${PORT_RALPH:-3000}:3000"
      - "${PORT_CLOUDCLI:-3001}:${CLOUDCLI_PORT:-3001}"
      - "${PORT_DEV:-9000}:9000"

    cap_add:
      - NET_ADMIN

    devices:
      - /dev/net/tun:/dev/net/tun

    stdin_open: true
    tty: true
```

启动：

```bash
cp .env.example .env   # 填写 API Key 等；其余预设可按需保留或留空
docker compose up -d
```

### docker run Example

```bash
docker run -d --name coding-agent \
  --restart unless-stopped \
  --env-file .env \
  -e DATA_ROOT=/data/coding-agent \
  -e TZ=Asia/Shanghai \
  -e NODE_ENV=development \
  -e GOPATH=/home/node/go \
  -e GOCACHE=/home/node/.cache/go-build \
  -e CLOUDCLI_ENABLE=true \
  -e CLOUDCLI_PORT=3001 \
  -p 8080:8080 \
  -p 3000:3000 \
  -p 3001:3001 \
  -p 9000:9000 \
  --cap-add NET_ADMIN \
  --device /dev/net/tun:/dev/net/tun \
  -v /data/coding-agent:/data/coding-agent \
  ghcr.io/moshall/coding_agent_docker:latest
```

### Port Notes

- `8080`、`3000`、`3001`、`9000` 是镜像预留的常用映射。默认 **CloudCLI** 在容器内监听 **`CLOUDCLI_PORT`（默认 `3001`）**，Compose 用 **`PORT_CLOUDCLI`→`CLOUDCLI_PORT`** 映射到宿主机（可用 `CLOUDCLI_ENABLE=false` 关闭进程，但端口行可保留无害）。
- 若修改 `CLOUDCLI_PORT`，`docker run` 须同步为 `-p <宿主机端口>:<CLOUDCLI_PORT>`。
- `8080`、`9000` 不代表一定有进程在监听。
- 如果你只把它当作纯 CLI 工作容器，可以删除 `ports:` 相关配置。
- 如果你需要让宿主机或其他容器访问容器内服务，服务本身需要监听 `0.0.0.0`；仅做 Docker 端口映射并不会自动改写应用的绑定地址。

## Common Operations

### Enter Shell

默认 `docker exec` 常常以 `root` 进入，但这个镜像推荐把日常操作落在 `node` 用户下。进入交互 shell 时请加上 **`-it`**，否则容易出现无行编辑、部分 CLI 排版异常等问题：

```bash
docker exec -it --user node -e NODE_ENV=production coding-agent bash
```

若在编排目录下使用 Compose：

```bash
docker compose exec -it --user node -e NODE_ENV=production coding-agent bash
```

说明：

- 容器启动后主进程会切换为 `node` 用户。
- 但你手动 `docker exec` 时，默认用户仍可能是 `root`。
- 如果你用 `root` 进入后执行普通命令，容易写出 root 权限的配置文件，后续再切回 `node` 时会遇到权限问题。

### 校验 Superpowers（Claude 官方插件）

默认开启时，安装在后台写入 `/var/log/entrypoint-skills.log`。仓库提供脚本，可在**有 Docker 的宿主机**上一键核对环境变量、日志与 `claude plugin list`：

```bash
chmod +x scripts/verify-superpowers-claude-plugin.sh
./scripts/verify-superpowers-claude-plugin.sh coding-agent
```

若 `.env` 中设为 `SUPERPOWERS_CLAUDE_PLUGIN_ENABLE=false`，脚本会说明为关闭态并直接退出成功。修改开关后需 `docker compose up -d`（必要时 `docker compose up -d --force-recreate`）再测。

### Use ccman

`ccman` 已做包装优化，行为如下：

- 即使你在 `root` shell 里执行 `ccman`，它也会自动切换为 `node` 用户运行。
- 会自动固定 `NODE_ENV=production`，避免配置落到 `/tmp/ccman-dev`。
- `ccman` 的配置会持久化到 `${DATA_ROOT}/config/ccman`。
- 通过 `ccman` 写入的 Claude、Codex、Gemini、OpenCode、OpenClaw 配置都会落在对应持久化目录中。

常用命令：

```bash
ccman cc add
ccman cc ls
ccman cc use <name>
ccman cc current

ccman cx add
ccman cx ls
ccman cx use <name>
ccman cx current
```

如果你只是想直接打开交互界面：

```bash
docker compose exec -it coding-agent ccman
```

### Check Runtime Version

容器内查看运行时版本元数据：

```bash
echo "$CODING_AGENT_VERSION"
echo "$CODING_AGENT_BUILD_DATE"
echo "$CODING_AGENT_VCS_REF"
echo "$CODING_AGENT_BOM_PATH"
```

构建时会把当时装机的 **npm / CLI / Python 库** 版本写入 **物料清单（BOM）**：

```bash
cat "$CODING_AGENT_BOM_PATH"
# 或
python3 -m json.tool "$CODING_AGENT_BOM_PATH"
```

镜像内全局 npm 由仓库 **`docker/npm-required.txt`**、**`docker/npm-optional.txt`** 固定版本；Python 由 **`docker/python-requirements.txt`** 固定。要发布「新工具版本基线」时，维护者在仓库里改这些文件并打 tag 即可；**用户不必跟着每次上游小版本漂移**。

可选：构建 **`cc-connect`** 时使用 git 分支/tag（默认可不填，拉取仓库默认分支 HEAD）：

```env
# 仅源码构建时传入 docker compose / build-arg
# CC_CONNECT_GIT_REF=v1.0.0
```

在宿主机查看镜像 OCI 标签：

```bash
docker inspect --format '{{ index .Config.Labels "org.opencontainers.image.version" }}' ghcr.io/moshall/coding_agent_docker:latest
```

**拉取不可变制品**：除 `v1.2.3`、`sha-abc…`、`date-YYYYMMDD` 等 tag 外，还可用 registry digest（`docker pull ghcr.io/…@sha256:…`）锁定某次构建。

## Build and Release

自动构建工作流见 [.github/workflows/build-push.yml](./.github/workflows/build-push.yml)。

### Trigger Rules

以下情况会触发构建：

- `main` 分支 push
- `v*` 版本 tag push
- 手动触发 `workflow_dispatch`
- 每日北京时间 `07:00` 的定时构建

### Publish Gates

只有通过以下检查后，镜像才会推送到 GHCR：

- `docker compose config` 检查
- `docker compose -f docker-compose.dev.yml build --no-cache`
- 容器启动就绪检查
- CLI 可用性回归
- 配置生成回归
- 持久化、`user-init.sh`、端口与技能初始化回归
- `node` 用户对 `~/.claude`、`~/.agents/skills` 可写（绑定挂载权限回归，避免 Claude 插件 / `npx skills` EACCES）

### Tag Strategy

| 标签 | 含义 | 是否适合生产固定版本 |
| --- | --- | --- |
| `latest` | 最新一次主干成功构建 | 否，适合跟进最新 |
| `sha-<12位提交哈希>` | 对应某次具体提交 | 是 |
| `date-YYYYMMDD` | 对应某日构建 | 视需求而定 |
| `vX.Y.Z` | 显式版本发布 | 是，最推荐 |

拉取示例：

```bash
docker pull ghcr.io/moshall/coding_agent_docker:latest
docker pull ghcr.io/moshall/coding_agent_docker:v1.0.1
```

## Troubleshooting

### 1Panel（或类似面板）报 `docker-compose config failed` / `invalid proto`

1. **一长串 `variable is not set` 警告**  
   旧版编排若写 `${ANTHROPIC_API_KEY}` 而无默认值，Compose 会打 warning。**部分面板把 stderr 里的 warning 当成失败。** 请使用本仓库最新 [`docker-compose.yml`](./docker-compose.yml)（密钥类已改为 **`${ANTHROPIC_API_KEY:-}`** 等，未设置时静默为空）。

2. **`compose.yml` 与 `.env` 同目录**  
   面板「工作目录」需与 `docker-compose.yml`、`.env` 一致；或在面板环境变量里补全同名键（否则仅 compose 内默认值生效）。

3. **`invalid proto`**  
   多为 **端口映射展开异常**（例如某环境变量被设成空、`8080:` 缺右侧）。请 SSH 到主机在编排目录执行：  
   `docker compose config`  
   若仍失败，检查 `ports:` 四行是否被面板改坏；可暂时改成固定数字（如 `3001:3001`）对照。

4. **命令名**  
   建议使用 **`docker compose`（V2 插件）**；若机器只有 **`docker-compose`（独立 v1）** 可能行为略有差异。

5. **拉取镜像 `invalid reference format`，日志出现字面量 `${DOCKER_IMAGE:-...}`**  
   面板在**预拉镜像**时可能不对 `image:` 做变量替换。请使用 **[deploy/1panel/docker-compose.yml](./deploy/1panel/docker-compose.yml)**（`image` 为固定字符串），或把 `image:` 改成 **`ghcr.io/moshall/coding_agent_docker:latest`** 等纯镜像名。

### `docker compose exec` 提示找不到配置文件

你需要在包含 `docker-compose.yml` 的目录执行，或者显式指定文件：

```bash
docker compose -f /path/to/docker-compose.yml exec -it coding-agent bash
```

### 容器启动了，但没有 Web 页面

默认会启动 **CloudCLI**（`CLOUDCLI_ENABLE` 默认为真），一般可访问**宿主机映射的 `PORT_CLOUDCLI`（默认 3001）**。若你显式关闭了 CloudCLI，或端口未映射 / 安全组未放行，则仍可能看不到页面；其它端口（如 `8080`、`9000`）未必有进程监听。

### `ccman` 配置后看起来没生效

优先使用镜像内的 `ccman` 包装命令，或者直接以 `node` 用户进入容器后再操作。避免把配置写成 root 所有者。

### 首次启动比较慢

也是预期行为。首次启动会做目录初始化、配置生成、skills/extensions 安装，以及可选运行时包的初始化。后续因持久化会明显更快。

### 本地无缓存构建占用空间较大

如果只是使用公开镜像，建议直接拉取 GHCR 版本；本地 `--no-cache` 构建会明显增加磁盘占用。

### Tailscale 无法启动

请确认宿主机提供了 `NET_ADMIN` 能力和 `/dev/net/tun` 设备；某些受限环境或 CI runner 不具备这些条件。

### Claude `superpowers` 插件装不上 / `claude plugin list` 为空

1. 确认容器能出网，且 `SUPERPOWERS_CLAUDE_PLUGIN_ENABLE` 不为 `false`。  
2. 看 **`/var/log/entrypoint-skills.log`**：若出现 **`EACCES`** 写入 `~/.claude/plugins`，多为 `${DATA_ROOT}/config/*` 在宿主机上属主为 root——请升级到当前镜像或使用「持久化」小节中的 **`chown 1000:1000`** 修复后再 `docker compose up -d --force-recreate`。  
3. 若日志提示 **`not found in marketplace claude-plugins-official`**：新镜像会优先走 **`obra/superpowers-marketplace`**；仍失败时请对照 [obra/superpowers 安装说明](https://github.com/obra/superpowers#claude-code-official-marketplace) 在容器内手动重试。  
4. 可用 **`scripts/verify-superpowers-claude-plugin.sh`** 做一键核对。

### `npx skills` / Codex 技能安装报 `EACCES`

与上类似：确保 **`${DATA_ROOT}/config/claude`**、**`config/agents`**、**`config/codex`** 对容器内 **uid 1000** 可写；推荐拉最新镜像或宿主机 `chown -R 1000:1000` 对应目录后重建容器。

## Related Docs

- [docker-compose.yml](./docker-compose.yml): 默认部署编排
- [docker-compose.dev.yml](./docker-compose.dev.yml): 本地构建与 CI 回归编排
- [.env.example](./.env.example): 环境变量模板
- [user-init.sh.example](./user-init.sh.example): 自定义启动脚本示例
- [CHANGELOG.md](./CHANGELOG.md): 版本变更记录
- [UPGRADING.md](./UPGRADING.md): 升级说明
- [CONTRIBUTING.md](./CONTRIBUTING.md): 贡献指南
- [SECURITY.md](./SECURITY.md): 安全说明
- [RELEASE_NOTES.md](./RELEASE_NOTES.md): 发布说明

## Support

- 使用问题、缺陷反馈或镜像异常，请在 [GitHub Issues](https://github.com/moshall/coding_agent_docker/issues) 提交。
- 版本发布与变更记录可在 [Releases](https://github.com/moshall/coding_agent_docker/releases) 查看。
- 如果你要贡献改进，可先阅读 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## License

遵循仓库中的 [LICENSE](./LICENSE) 文件。
