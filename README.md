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
| Superpowers | `SUPERPOWERS_CLAUDE_PLUGIN_ENABLE`（默认 `true`） | Claude 侧官方插件安装（需出网）；`false` 可关闭；Codex 侧由 entrypoint 按上游 `INSTALL.md` 建链 |
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

### 1Panel / `DATA_ROOT` 在 `/root/...` 下

面板常把应用数据放在 root 家目录下。Debian 系镜像里 **`/root` 默认 0700**，容器内用户 **`node`（uid 1000）无法进入**其子路径，CloudCLI、写 `DATA_ROOT` 会报权限错误。

**兼容方式（已由 entrypoint 自动处理）**：若检测到 `DATA_ROOT` 以 `/root/` 开头，启动时（仍以 root 运行阶段）会对**容器内** `/root` 执行 **`chmod 0711`**：允许按路径进入子目录，但其它用户**不能** `ls /root`。无需你在宿主机上改 `/root` 权限；若编排使用只读根文件系统导致 `chmod` 失败，请把数据目录改到 `/data`、`/opt` 等，或按面板文档使用其推荐的挂载路径。

<details>
<summary>展开：config / software 下常见子路径（自动创建，一般不必手改）</summary>

- `config/claude`、`config/codex`、`config/superpowers`、`config/ccman`、`config/gemini`、`config/gemini-home`、`config/opencode`、`config/taskmaster`、`config/gh`、`config/agents`
- `software/tailscale`、`software/go`、`software/go-build-cache`、`software/cron/crontabs`、`software/bootstrap`、`software/cloudcli-xdg`（CloudCLI 状态与 DB，避免 `~/.config/cloudcli` 符号链接触发 Node `mkdir` 报错）

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
      # CloudCLI（claudecodeui）；默认同仓库 docker-compose.yml
      - CLOUDCLI_ENABLE=${CLOUDCLI_ENABLE:-true}
      - CLOUDCLI_PORT=${CLOUDCLI_PORT:-3001}

    volumes:
      - /data/coding-agent:/data/coding-agent

    ports:
      # 与仓库 docker-compose.yml 一致：宿主机端口可用 PORT_*，CloudCLI 容器内端口为 CLOUDCLI_PORT
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

默认 `docker exec` 常常以 `root` 进入，但这个镜像推荐把日常操作落在 `node` 用户下：

```bash
docker compose exec --user node -e NODE_ENV=production coding-agent bash
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
docker compose exec coding-agent ccman
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
