# coding_agent_docker

一套可直接落地的 Coding Agent Docker 运行环境，内置多种 AI CLI、数据分析工具链与自动初始化流程，并通过 **GHCR + GitHub Actions** 做持续构建发布。

- 公开镜像地址：`ghcr.io/moshall/coding_agent_docker`
- 推荐标签：`latest`
- 自动构建时间：**每日北京时间 07:00**（GitHub cron: `0 23 * * *`）

---

## 1. 项目定位与应用场景

这个镜像适合以下场景：

1. **个人开发工作台容器化**
   在任意 Linux 主机快速拉起统一的 AI 开发环境，避免本机反复安装 CLI。

2. **团队共享一致环境**
   团队成员使用同一镜像，降低“你本地能跑、我本地不行”的环境偏差。

3. **远程 VPS / 云主机开发**
   在远程服务器中长期运行，结合 `tmux`、`cron`、持久化目录做稳定工作流。

4. **CI/CD 验证镜像能力**
   每日自动构建并跑回归检查，保证镜像持续可用。

---

## 2. 镜像内容与作用

### 2.1 基础运行时

- `node:22-bookworm`（主运行环境）
- `golang`（构建/运行 Go 生态工具）
- `python3 + pip`（数据分析、脚本任务）
- `rustup + rust stable`（Rust 工具链）

### 2.2 预装 AI CLI

- `@anthropic-ai/claude-code`：Claude Code CLI
- `@openai/codex`：Codex CLI
- `@google/gemini-cli`：Gemini CLI
- `opencode-ai`：OpenCode CLI
- `task-master-ai`：Task Master CLI
- `ccman`：Claude Code 管理工具
- `uipro-cli`：UI Pro 初始化工具
- `cc-connect`：Go 二进制（多路径构建 + fallback）

### 2.3 数据与开发工具

- Python 科学栈：`pandas` `matplotlib` `seaborn` `scipy`
- 命令行/运维：`gh` `tmux` `cron` `git` `curl` `wget`
- 网络组件：`tailscale`（含 `tailscaled`）

### 2.4 启动逻辑（entrypoint）

容器启动时会自动完成：

1. 初始化配置目录与权限
2. 启动 `cron`
3. 启动 `tailscaled`（有 `TAILSCALE_AUTHKEY` 时自动 `tailscale up`）
4. 自动生成缺失配置文件（Claude/Codex/Gemini/Task Master）
5. 后台安装 skills/extensions（不阻塞终端）
6. 可选执行 `${DATA_ROOT}/user-init.sh`
7. 最终切换到 `node` 用户

---

## 3. 预装 Skill 信息

启动后会按“缺失才安装”的策略处理以下技能（幂等）：

1. `planning-with-files`
   - 来源：`OthmanAdi/planning-with-files`
   - 作用：复杂任务拆分、计划文件化管理

2. `data-analyst`
   - 来源：镜像内 `/home/node/.openclaw-skills/data-analyst`
   - 作用：数据分析辅助能力（复制到 `.claude/skills` 与 `.codex/skills`）

3. `oil-oil/codex`
   - 来源：`oil-oil/codex`
   - 作用：Codex 相关 skill 增强

4. `ui-ux-pro-max` 初始化
   - 工具：`uipro init --offline`
   - 作用：为 `codex/gemini/opencode` 做扩展初始化

> 说明：skill 安装在后台执行，日志位于 `/var/log/entrypoint-skills.log`。

---

## 4. 持久化方式说明（重点）

采用三层持久化模型：

1. **Layer 1：配置持久化（自动托管）**
   - 主机目录：`${DATA_ROOT}/config/*`
   - 容器目录：`/home/node/.claude` `/home/node/.codex` `/home/node/.config/gemini` `/home/node/.task-master` 等

2. **Layer 2：项目工作区**
   - 主机目录：`${DATA_ROOT}/projects`
   - 容器目录：`/home/node/projects`

3. **Layer 3：可选外部挂载**
   - `MOUNT_OPENCLAW`
   - `MOUNT_EXTRA_1/2/3`

此外，`DATA_ROOT` 根目录本身也会映射到容器同路径，用于执行：
- `${DATA_ROOT}/user-init.sh`（用户自定义初始化脚本）

---

## 5. 配置说明（.env）

复制模板：

```bash
cp .env.example .env
```

### 5.1 先看结论：哪些不填会报错？

按当前 `docker-compose.yml` 与 `entrypoint.sh` 实现：

1. **没有“必填才可启动”的硬性项**
   - 不填多数变量时，`docker compose` 会给 warning 并注入空字符串或默认值，不会直接阻断启动。
2. **“必填”取决于你要用的功能**
   - 比如要用 Claude/Codex/Gemini/Task Master 某 provider，就必须填对应 API Key。

### 5.2 按功能划分（推荐）

1. 基础运行（有默认值，可不填）
   - `DATA_ROOT`（默认 `/data/coding-agent`）
   - `CONTAINER_NAME`（默认 `coding-agent`）
   - `TZ`（默认 `Asia/Shanghai`）
   - `NODE_ENV`（默认 `development`）
   - `PORT_CC_CONNECT`（默认 `8080`）
   - `PORT_RALPH`（默认 `3000`）
   - `PORT_DEV`（默认 `9000`）
   - `DOCKER_IMAGE`（默认 `ghcr.io/moshall/coding_agent_docker:latest`）
   - `TASKMASTER_MAIN_PROVIDER`（默认 `anthropic`）
   - `TASKMASTER_MAIN_MODEL`（默认 `claude-sonnet-4-20250514`）
   - `TAILSCALE_HOSTNAME`（默认 `coding-agent`）
   - `CODEX_MODEL`（默认 `gpt-5-codex`）

2. 按功能必填（不用对应功能可留空）
   - `ANTHROPIC_API_KEY`
     - 需要 Claude CLI，或 Task Master 主 provider/fallback/research 使用 `anthropic` 时必填。
   - `OPENAI_API_KEY`
     - 需要 Codex CLI，或 Task Master 使用 `openai` 时必填。
   - `GEMINI_API_KEY`
     - 需要 Gemini CLI 时必填。
   - `OPENROUTER_API_KEY`
     - Task Master 使用 `openrouter` provider 时必填。
   - `PERPLEXITY_API_KEY`
     - Task Master research provider 使用 `perplexity` 时必填。

3. 完全可选（不影响基础启动）
   - 代理与网关：`ANTHROPIC_BASE_URL` `OPENAI_BASE_URL`
   - Task Master 研究与兜底：`TASKMASTER_RESEARCH_PROVIDER` `TASKMASTER_RESEARCH_MODEL` `TASKMASTER_FALLBACK_PROVIDER` `TASKMASTER_FALLBACK_MODEL`
   - GitHub CLI：`GH_TOKEN`
   - Tailscale：`TAILSCALE_AUTHKEY`
   - 可选挂载：`MOUNT_OPENCLAW` `MOUNT_EXTRA_1` `MOUNT_EXTRA_2` `MOUNT_EXTRA_3`

### 5.3 最小可用配置示例

如果你只想先把容器跑起来并使用 Claude + Codex，最小可用可先填：

```env
ANTHROPIC_API_KEY=your_anthropic_key
OPENAI_API_KEY=your_openai_key
```

其余保持 `.env.example` 默认值即可，后续按需补充。

---

## 6. 如何拉取和使用

### 6.1 直接拉取镜像

```bash
docker pull ghcr.io/moshall/coding_agent_docker:latest
```

### 6.2 使用 Compose 启动（推荐）

```bash
cp .env.example .env
# 编辑 .env 填入你的密钥

docker compose up -d
docker compose exec coding-agent bash
```

### 6.3 运行后快速自检

```bash
claude --version
codex --version
gemini --version
task-master --version
```

---

## 7. 自动构建与发布时间

仓库内置工作流：
- 文件：`.github/workflows/build-push.yml`
- 触发条件：
  1. `main` 分支 push
  2. 手动触发 `workflow_dispatch`
  3. 定时触发 `schedule`（每日北京时间 07:00）

发布门禁：

1. `docker compose config` 检查
2. `--no-cache` 全量构建
3. 容器启动就绪检查
4. 多项回归（CLI/配置/Rust/持久化/user-init 等）
5. 仅全部通过后才推送 GHCR

标签策略：

- `latest`
- `sha-<12位提交哈希>`
- `date-YYYYMMDD`

### 7.1 构建耗时说明

- 日常 no-cache 构建 + 回归，通常在 **15~40 分钟**（受网络与 GitHub runner 资源波动影响）
- 实际时间以 Actions 每次运行记录为准

---

## 8. 让他人直接拉取使用

可以，前提是：

1. GitHub 仓库是公开的
2. GHCR 包可见性设为 `public`

设置路径：
- GitHub 仓库页面 -> Packages -> 选择 `coding_agent_docker` 包 -> Package settings -> Change visibility -> `Public`

完成后，他人可匿名拉取：

```bash
docker pull ghcr.io/moshall/coding_agent_docker:latest
```

---

## 9. 注意事项

1. **密钥安全**
   - `.env` 含敏感信息，不要提交到 git
   - 建议按环境分发不同密钥

2. **磁盘空间**
   - no-cache 构建会占用较大空间
   - 建议预留至少 35GB 可用空间

3. **Tailscale 运行条件**
   - 需要 `NET_ADMIN` 与 `/dev/net/tun`
   - 某些 CI runner 不具备该能力，需跳过或降级检查

4. **首次启动耗时**
   - 首次会进行配置生成与 skill 初始化
   - 后续因持久化会明显更快

5. **可选挂载默认是 /dev/null 占位**
   - 不配置 `MOUNT_*` 时为占位策略，属于预期行为

6. **镜像默认目标**
   - `docker-compose.yml` 默认拉取 GHCR 的 `latest`
   - 如需固定版本，建议改为 `sha-*` 或 `date-*` 标签

---

## 10. 常用运维命令

```bash
# 查看容器状态
docker compose ps

# 查看启动日志
docker compose logs --tail=200 coding-agent

# 进入容器
docker compose exec coding-agent bash

# 重建（本地）
docker compose -f docker-compose.dev.yml build --no-cache

# 重启
docker compose restart coding-agent

# 停止并清理
docker compose down
```

---

## 11. 回归基线（当前）

在 Debian 12 与 Ubuntu 22.04 环境均完成过完整回归，核心检查包括：

- `PID1=node`、`restart=0`
- 多 CLI 可用性
- 配置自动生成正确性
- `wire_api = "responses"`
- Rust toolchain 可用
- `user-init.sh` 生效
- host/container 双向持久化

---

## 12. 许可证

遵循仓库中的 `LICENSE` 文件。
