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
| AI CLI | `claude-code`、`codex`、`gemini-cli`、`opencode`、`task-master` | 镜像内预装 |
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
- 后台安装 skills/extensions，不阻塞主终端。
- 如存在 `${DATA_ROOT}/user-init.sh`，则在启动时执行。
- 最终把主进程切换为 `node` 用户。

### Bundled Skills and Extensions

镜像会按幂等方式初始化以下内容：

- `planning-with-files`
- `data-analyst`
- `oil-oil/codex`
- `uipro init --offline` 相关扩展初始化

说明：这部分在后台执行，日志位于 `/var/log/entrypoint-skills.log`。

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

推荐直接以 `node` 用户进入：

```bash
docker compose exec --user node -e NODE_ENV=production coding-agent bash
```

如果你用的是 `docker exec`：

```bash
docker exec -it --user node -e NODE_ENV=production coding-agent bash
```

### 4. Smoke Check

```bash
claude --version
codex --version
gemini --version
task-master --version
ccman --version
```

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
| 可选运行时增强 | `INSTALL_GO_RUNTIME`、`INSTALL_BUILD_ESSENTIAL` | 留空表示关闭，设为 `true` 表示启动时安装，并将选择持久化 |
| 可选额外挂载 | `MOUNT_OPENCLAW`、`MOUNT_EXTRA_1/2/3` | 用于挂载外部工作区或资源目录 |

### Optional Runtime Package Switches

这两个变量是“开关型变量”，不是必填项：

- `GOPATH`、`GOCACHE` 只是目录位置定义，建议保留，不会因为存在就自动安装 Go。
- `INSTALL_GO_RUNTIME=` 和 `INSTALL_BUILD_ESSENTIAL=` 留空时，表示关闭。
- `INSTALL_GO_RUNTIME=true` 或 `INSTALL_BUILD_ESSENTIAL=true` 时，表示在容器启动时安装对应运行时包。

需要特别注意的是，这两个开关带“持久化记忆”：

- 一旦开启过，启动脚本会写入 `${DATA_ROOT}/config/bootstrap/install-go-runtime`
- 或 `${DATA_ROOT}/config/bootstrap/install-build-essential`

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

### Three Layers

| 层级 | 主机侧 | 容器侧 | 作用 |
| --- | --- | --- | --- |
| Layer 1 | `${DATA_ROOT}/config/*` | 各工具配置目录 | 持久化授权、配置、缓存和工具状态 |
| Layer 2 | `${DATA_ROOT}/projects` | `/home/node/projects` | 持久化项目源码和工作区 |
| Layer 3 | `MOUNT_OPENCLAW`、`MOUNT_EXTRA_*` | `/home/node/openclaw`、`/home/node/workspace-*` | 可选外部挂载 |

额外约定：

- `${DATA_ROOT}/config/bootstrap/*` 用来记录是否启用了 `golang` / `build-essential` 的运行时安装。
- `${DATA_ROOT}/user-init.sh` 可作为用户自定义启动脚本。
- `${DATA_ROOT}` 根目录本身会映射到容器内同路径，便于脚本和附加资源直接访问。

<details>
<summary>展开查看主要持久化目录映射</summary>

- `${DATA_ROOT}/config/claude` -> `/home/node/.claude`
- `${DATA_ROOT}/config/codex` -> `/home/node/.codex`
- `${DATA_ROOT}/config/ccman` -> `/home/node/.ccman`
- `${DATA_ROOT}/config/gemini` -> `/home/node/.config/gemini`
- `${DATA_ROOT}/config/gemini-home` -> `/home/node/.gemini`
- `${DATA_ROOT}/config/opencode` -> `/home/node/.config/opencode`
- `${DATA_ROOT}/config/openclaw-home` -> `/home/node/.openclaw`
- `${DATA_ROOT}/config/taskmaster` -> `/home/node/.task-master`
- `${DATA_ROOT}/config/gh` -> `/home/node/.config/gh`
- `${DATA_ROOT}/config/tailscale` -> `/var/lib/tailscale`
- `${DATA_ROOT}/config/go` -> `/home/node/go`
- `${DATA_ROOT}/config/go-build-cache` -> `/home/node/.cache/go-build`
- `${DATA_ROOT}/cron/crontabs` -> `/var/spool/cron/crontabs`
- `${DATA_ROOT}/projects` -> `/home/node/projects`

</details>

## Deployment Examples

### Compose Template

仓库内已经提供可直接使用的 [docker-compose.yml](./docker-compose.yml)。
如果你想复制一份最常用的公开镜像编排模板，可以使用下面这个版本：

```yaml
services:
  coding-agent:
    image: ghcr.io/moshall/coding_agent_docker:latest
    container_name: coding-agent
    restart: unless-stopped

    env_file:
      - .env

    environment:
      - DATA_ROOT=/data/coding-agent
      - TZ=Asia/Shanghai
      - NODE_ENV=development
      - GOPATH=/home/node/go
      - GOCACHE=/home/node/.cache/go-build
      - INSTALL_GO_RUNTIME=
      - INSTALL_BUILD_ESSENTIAL=

    volumes:
      # 数据根目录，保留配置、项目与 user-init.sh
      - /data/coding-agent:/data/coding-agent
      # 项目工作区
      - /data/coding-agent/projects:/home/node/projects
      # Claude Code 配置与登录态
      - /data/coding-agent/config/claude:/home/node/.claude
      # Codex 配置与登录态
      - /data/coding-agent/config/codex:/home/node/.codex
      # ccman provider 配置
      - /data/coding-agent/config/ccman:/home/node/.ccman
      # Gemini 配置
      - /data/coding-agent/config/gemini:/home/node/.config/gemini
      - /data/coding-agent/config/gemini-home:/home/node/.gemini
      # OpenCode / OpenClaw / Task Master
      - /data/coding-agent/config/opencode:/home/node/.config/opencode
      - /data/coding-agent/config/openclaw-home:/home/node/.openclaw
      - /data/coding-agent/config/taskmaster:/home/node/.task-master
      # Go 持久化
      - /data/coding-agent/config/go:/home/node/go
      - /data/coding-agent/config/go-build-cache:/home/node/.cache/go-build

    ports:
      # 8080: 预留给 cc-connect 或桥接服务
      - "8080:8080"
      # 3000: 预留给 Ralph / Web UI 类服务
      - "3000:3000"
      # 9000: 通用开发或调试端口
      - "9000:9000"

    cap_add:
      - NET_ADMIN

    devices:
      - /dev/net/tun:/dev/net/tun

    stdin_open: true
    tty: true
```

启动：

```bash
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
  -p 8080:8080 \
  -p 3000:3000 \
  -p 9000:9000 \
  --cap-add NET_ADMIN \
  --device /dev/net/tun:/dev/net/tun \
  -v /data/coding-agent:/data/coding-agent \
  -v /data/coding-agent/projects:/home/node/projects \
  -v /data/coding-agent/config/claude:/home/node/.claude \
  -v /data/coding-agent/config/codex:/home/node/.codex \
  -v /data/coding-agent/config/ccman:/home/node/.ccman \
  -v /data/coding-agent/config/gemini:/home/node/.config/gemini \
  -v /data/coding-agent/config/gemini-home:/home/node/.gemini \
  -v /data/coding-agent/config/opencode:/home/node/.config/opencode \
  -v /data/coding-agent/config/openclaw-home:/home/node/.openclaw \
  -v /data/coding-agent/config/taskmaster:/home/node/.task-master \
  -v /data/coding-agent/config/go:/home/node/go \
  -v /data/coding-agent/config/go-build-cache:/home/node/.cache/go-build \
  ghcr.io/moshall/coding_agent_docker:latest
```

### Port Notes

- `8080`、`3000`、`9000` 是镜像预留的常用映射，不代表容器启动后一定默认已有进程监听。
- 如果你只把它当作纯 CLI 工作容器，可以删除 `ports:` 相关配置。
- 如果你需要让宿主机或其他容器访问容器内服务，服务本身需要监听 `0.0.0.0`；仅做 Docker 端口映射并不会自动改写应用的绑定地址。

## Common Operations

### Enter Shell

默认 `docker exec` 常常以 `root` 进入，但这个镜像推荐把日常操作落在 `node` 用户下：

```bash
docker compose exec --user node -e NODE_ENV=production coding-agent bash
```

说明：

- 容器启动后主进程会切换为 `node` 用户。
- 但你手动 `docker exec` 时，默认用户仍可能是 `root`。
- 如果你用 `root` 进入后执行普通命令，容易写出 root 权限的配置文件，后续再切回 `node` 时会遇到权限问题。

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
docker compose exec coding-agent ccman
```

### Check Runtime Version

容器内查看运行时版本元数据：

```bash
echo "$CODING_AGENT_VERSION"
echo "$CODING_AGENT_BUILD_DATE"
echo "$CODING_AGENT_VCS_REF"
```

在宿主机查看镜像 OCI 标签：

```bash
docker inspect --format '{{ index .Config.Labels "org.opencontainers.image.version" }}' ghcr.io/moshall/coding_agent_docker:latest
```

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

### `docker compose exec` 提示找不到配置文件

你需要在包含 `docker-compose.yml` 的目录执行，或者显式指定文件：

```bash
docker compose -f /path/to/docker-compose.yml exec coding-agent bash
```

### 容器启动了，但没有 Web 页面

这是预期行为。这个镜像的默认定位是通用 CLI 工作容器，端口只是预留映射，不代表默认就有某个 Web 服务在监听。

### `ccman` 配置后看起来没生效

优先使用镜像内的 `ccman` 包装命令，或者直接以 `node` 用户进入容器后再操作。避免把配置写成 root 所有者。

### 首次启动比较慢

也是预期行为。首次启动会做目录初始化、配置生成、skills/extensions 安装，以及可选运行时包的初始化。后续因持久化会明显更快。

### 本地无缓存构建占用空间较大

如果只是使用公开镜像，建议直接拉取 GHCR 版本；本地 `--no-cache` 构建会明显增加磁盘占用。

### Tailscale 无法启动

请确认宿主机提供了 `NET_ADMIN` 能力和 `/dev/net/tun` 设备；某些受限环境或 CI runner 不具备这些条件。

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
