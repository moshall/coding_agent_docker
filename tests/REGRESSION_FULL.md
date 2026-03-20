# Coding Agent Docker — 完整回归用例（总表）

本文档整合：

- 仓库内**静态脚本** `tests/run-all.sh`（全部 `TC-*` / 冒烟断言）
- **GitHub Actions** [`.github/workflows/build-push.yml`](../.github/workflows/build-push.yml) 中构建与容器内检查
- **真机/准生产** 扩展项（与 [`MANUAL_REAL_MACHINE_CHECKLIST.md`](./MANUAL_REAL_MACHINE_CHECKLIST.md) 一致，此处只列索引）

与当前产品模型对齐的要点：**`DATA_ROOT` 主卷 + `project:/home/node/project` 工作区别名挂载**（`project` / `config` / `software`）、**CloudCLI（claudecodeui）**、**无 openclaw 专用挂载与 openclaw/skills 克隆**、**npm/pip 锁文件 + 镜像内 `bom.json`**。

---

## 一、如何一键跑静态回归

在仓库根目录：

```bash
bash tests/run-all.sh
```

预期末尾：`All regression scripts completed`；各脚本 Summary 为 `fail=0`。

---

## 二、静态用例全目录（按 `run-all.sh` 执行顺序）

### 2.1 `tc-smoke.sh`（核心文件与关键内容）

| 断言 | 说明 |
|------|------|
| Dockerfile / entrypoint.sh / docker-compose.yml / docker-compose.dev.yml 存在 | 工程骨架 |
| `.env.example` / `user-init.sh.example` / `README.md` / `build-push.yml` 存在 | 模板与 CI |
| Dockerfile：`FROM golang:1.25-bookworm AS go-builder` | Go 构建段 |
| Dockerfile：`FROM node:22-bookworm` | 运行段 |
| entrypoint：`exec gosu node "$@"` | 运行时切 `node` |
| compose：`NET_ADMIN` | Tailscale 能力 |
| compose：`'${DATA_ROOT:-/data/coding-agent}:${DATA_ROOT:-/data/coding-agent}'` | **单数据根挂载** |
| `.env.example`：`TASKMASTER_MAIN_PROVIDER` | 环境模板 |

---

### 2.2 `tc-build.sh`（TC-BUILD）

| ID | 说明 |
|----|------|
| TC-BUILD-01 | `Dockerfile` 存在 |
| TC-BUILD-02 | Go 构建段 `golang:1.25-bookworm` |
| TC-BUILD-03 | Node 运行段 `node:22-bookworm` |
| TC-BUILD-04 | `COPY --from=go-builder ... cc-connect` |
| TC-BUILD-05 | `CC_CONNECT_REPO=chenhg5/cc-connect` |
| TC-BUILD-05b | `ARG CC_CONNECT_GIT_REF`（可选固定 cc-connect ref） |
| TC-BUILD-15 | `record-bom.sh`（**构建时写 BOM**） |
| TC-BUILD-16 | `docker/python-requirements.txt`（**pip 锁**） |
| TC-BUILD-06 | fallback build：`GO111MODULE=off GOTOOLCHAIN=local` |
| TC-BUILD-07 | 运行镜像**不**含 apt `golang` |
| TC-BUILD-08 | 运行镜像**不**含 apt `build-essential` |
| TC-BUILD-09 | entrypoint：可选运行时包安装 |
| TC-BUILD-10 | entrypoint **无** Rust 自举文案 |
| TC-BUILD-11 | Dockerfile **无** `~/.cargo/bin` PATH |
| TC-BUILD-12 | Dockerfile **不**在构建期 clone superpowers |
| TC-BUILD-13 | Dockerfile **不** clone openclaw/skills |
| TC-BUILD-14 | entrypoint 仅运行时 sync `obra/superpowers` |

---

### 2.3 `tc-user.sh`（TC-USER）

| ID | 说明 |
|----|------|
| TC-USER-01 | `entrypoint.sh` 存在 |
| TC-USER-02 | `gosu node` 切换 |

---

### 2.4 `tc-tool.sh`（TC-TOOL）

| ID | 说明 |
|----|------|
| TC-TOOL-01 | `docker/npm-required.txt` 含 `@anthropic-ai/claude-code@` |
| TC-TOOL-02 | 同上含 `@openai/codex@` |
| TC-TOOL-03 | Dockerfile **无** `@google/gemini-cli` |
| TC-TOOL-04 | Dockerfile **无** `opencode-ai` |
| TC-TOOL-05 | npm 锁含 `task-master-ai@` |
| TC-TOOL-06 | Dockerfile 支持 `GH_VERSION` 固定安装 |
| TC-TOOL-07 | npm 锁含 `@siteboon/claude-code-ui@`（**CloudCLI**） |
| TC-TOOL-07b | Dockerfile 使用 `npm-required.txt` 安装 |
| TC-TOOL-08 | entrypoint：`maybe_start_cloudcli` |
| TC-TOOL-09 | `cloudcli-wrapper.sh` 存在 |
| TC-TOOL-10 | Dockerfile 安装 `cloudcli-wrapper.sh` |
| TC-TOOL-11 | entrypoint 传递 `WORKSPACES_ROOT` |
| TC-TOOL-12 | `cloudcli-wrapper` 包含 Python socket 端口检测兜底 |

---

### 2.4b `tc-configcli.sh`（TC-CONFIGCLI）

| ID | 说明 |
|----|------|
| TC-CONFIGCLI-01 | `codingagentconfig.sh` 存在 |
| TC-CONFIGCLI-02 | Dockerfile 安装 `/usr/local/bin/codingagentconfig` |
| TC-CONFIGCLI-03 | 菜单含快捷配置服务商入口 |
| TC-CONFIGCLI-04 | 菜单可触发 `ccman` |
| TC-CONFIGCLI-05 | 更新菜单包含 `claudecodeui` |
| TC-CONFIGCLI-06 | 工作区创建使用 `CLOUDCLI_DEFAULT_WORKSPACE_PATH` |
| TC-CONFIGCLI-07 | 工作区名英文校验 |
| TC-CONFIGCLI-08 | 主菜单包含 `Health status` |
| TC-CONFIGCLI-09 | 健康检查包含 `cron process` |
| TC-CONFIGCLI-10 | 健康检查包含 `cloudcli HTTP` |
| TC-CONFIGCLI-11 | 主菜单包含 `cc-connect quick bind` |
| TC-CONFIGCLI-12 | 快绑逻辑写入 `.cc-connect/config.toml` |
| TC-CONFIGCLI-13 | 快绑支持 `Telegram` |
| TC-CONFIGCLI-14 | 快绑支持 `Discord` |
| TC-CONFIGCLI-15 | 快绑支持 `Feishu` |
| TC-CONFIGCLI-16 | 主菜单包含 `cc-connect connection self-check` |
| TC-CONFIGCLI-17 | 自检逻辑读取 `cc_connect_config_path` |
| TC-CONFIGCLI-18 | 自检包含凭据字段检查（`Credentials:`） |
| TC-CONFIGCLI-19 | 自检包含 `cc-connect process` |
| TC-CONFIGCLI-20 | 自检包含 `cc-connect listening` |

---

### 2.5 `tc-ccman.sh`（TC-CCMAN）

| ID | 说明 |
|----|------|
| TC-CCMAN-01 | `ccman-wrapper.sh` 存在 |
| TC-CCMAN-02 | wrapper：`gosu node env` |
| TC-CCMAN-03 | wrapper：`NODE_ENV=production` |
| TC-CCMAN-04 | wrapper：`XDG_CONFIG_HOME` |
| TC-CCMAN-05 | entrypoint：`ensure_ln_home` → `.ccman` / `DATA_ROOT` |
| TC-CCMAN-06 | entrypoint **无** `openclaw` |
| TC-CCMAN-07 | entrypoint 创建 `.ccman` 目标 |

---

### 2.6 `tc-gemini.sh`（TC-GEMINI）

| ID | 说明 |
|----|------|
| TC-GEMINI-01 | `GEMINI_PROJECT_REGISTRY` 路径 |
| TC-GEMINI-02 | 种子 `projects.json` |

---

### 2.7 `tc-versioning.sh`（TC-VERSION）

| ID | 说明 |
|----|------|
| TC-VERSION-01～04 | workflow：`tags`、`v*`、version tag 计算与推送 |
| TC-VERSION-05 | `ARG BUILD_VERSION` |
| TC-VERSION-06 | OCI label `org.opencontainers.image.version` |
| TC-VERSION-07 | `CODING_AGENT_VERSION` |
| TC-VERSION-08 | README：`vX.Y.Z` 文档 |
| TC-VERSION-09 | `CODING_AGENT_BOM_PATH` → `bom.json` |

---

### 2.8 `tc-persist.sh`（TC-PERSIST）

| ID | 说明 |
|----|------|
| TC-PERSIST-01 | compose 包含 `DATA_ROOT:DATA_ROOT` 主卷 |
| TC-PERSIST-01b | compose 包含 `${DATA_ROOT}/project:/home/node/project` |
| TC-PERSIST-02 | compose **无** `config/claude:/home/node/.claude` |
| TC-PERSIST-03 | `link_persistence_from_data_root` |
| TC-PERSIST-04 | compose **无** cargo 卷 |
| TC-PERSIST-05 | `ensure_ln_home` → `/home/node/project` |
| TC-PERSIST-05b | 识别 `/home/node/project` 绑定挂载（避免误改符号链接） |
| TC-PERSIST-06 | `TASKMASTER_ENV` 生成 |
| TC-PERSIST-07 | `DATA_ROOT` 在 `/root/*` 时 `ensure_data_root_traversable_for_node`（1Panel） |

---

### 2.9 `tc-mount.sh`（TC-MOUNT）

| ID | 说明 |
|----|------|
| TC-MOUNT-01 | compose **无** `MOUNT_OPENCLAW` / `MOUNT_EXTRA_*` |
| TC-MOUNT-02 | entrypoint：遗留 `${DATA_ROOT}/projects` |
| TC-MOUNT-03 | README：**自行**加卷 |

---

### 2.10 `tc-userinit.sh`（TC-USERINIT）

| ID | 说明 |
|----|------|
| TC-USERINIT-01 | `user-init.sh.example` |
| TC-USERINIT-02 | `USER_INIT=${DATA_ROOT}/user-init.sh` |
| TC-USERINIT-03 | `running user-init.sh` |

---

### 2.11 `tc-env.sh`（TC-ENV）

| ID | 说明 |
|----|------|
| TC-ENV-01 | `.env.example` |
| TC-ENV-02 | `TASKMASTER_MAIN_PROVIDER` |
| TC-ENV-03 | Codex `wire_api = "responses"` |
| TC-ENV-04～05 | `INSTALL_GO_RUNTIME` / `INSTALL_BUILD_ESSENTIAL` |

---

### 2.12 `tc-workflow.sh`（TC-WORKFLOW）

| ID | 说明 |
|----|------|
| TC-WORKFLOW-01 | CI：`cc-connect --help` |
| TC-WORKFLOW-02 | CI：拒绝 `fallback build` |
| TC-WORKFLOW-03 | CI：拒绝 ccman `[开发模式]` |
| TC-WORKFLOW-04 | CI：**无** rust toolchain 要求 |

---

### 2.13 `tc-cron.sh`（TC-CRON）

| ID | 说明 |
|----|------|
| TC-CRON-01 | Dockerfile：`cron` |
| TC-CRON-02 | entrypoint：`starting cron` |

---

### 2.14 `tc-tmux.sh`（TC-TMUX）

| ID | 说明 |
|----|------|
| TC-TMUX-01 | Dockerfile：`tmux` |
| TC-TMUX-02 | README：`tmux` |

---

### 2.15 `tc-tailscale.sh`（TC-TAILSCALE）

| ID | 说明 |
|----|------|
| TC-TAILSCALE-01 | compose：`NET_ADMIN` |
| TC-TAILSCALE-02 | `/dev/net/tun` |
| TC-TAILSCALE-03 | Dockerfile：`apt install tailscale` |

---

### 2.16 `tc-skills.sh`（TC-SKILLS）

| ID | 说明 |
|----|------|
| TC-SKILLS-01～03 | planning-with-files、oil-oil/codex、ui-ux-pro-max |
| TC-SKILLS-04～04c | superpowers sync / Codex layout / Claude 插件 |
| TC-SKILLS-05 | **无** openclaw/skills URL |
| TC-SKILLS-06～07 | `DATA_ROOT/config/superpowers`、`config/agents` |
| TC-SKILLS-08 | compose **无** `openclaw-skills` 卷 |

---

### 2.17 `tc-port.sh`（TC-PORT）

| ID | 说明 |
|----|------|
| TC-PORT-01～04 | `.env.example`：`PORT_CC_CONNECT`、`PORT_RALPH`、`PORT_DEV`、`PORT_CLOUDCLI` |

---

### 2.18 `tc-release.sh`（TC-RELEASE）

| ID | 说明 |
|----|------|
| TC-RELEASE-01～03 | `DOCKER_HUB_DESCRIPTION.md`、`RELEASE_NOTES.md`、`UPGRADING.md` |

---

## 三、CI 流水线中的检查（`build-push.yml`）

下列步骤在推送/定时/workflow_dispatch 时执行（摘要）。

### 3.1 构建前门闸

| 步骤 | 说明 |
|------|------|
| Checkout | 源码 |
| Reclaim disk | 为本镜像腾出空间 |
| Compute tags | `latest` / `sha-*` / `date-*` / 版本 tag |
| Login GHCR | 凭 `GITHUB_TOKEN` |
| Prepare `.env` + `.ci-data` | CI 专用数据根与 `user-init.sh` |
| **Compose config** | `docker compose -f docker-compose.dev.yml config` |
| **/dev/net/tun** | runner 上创建或 chmod（便于 tailscaled） |
| **Build** | `docker compose ... build --no-cache` |
| **Up** | `up -d --force-recreate` |
| **Wait readiness** | 最多 30×5s：`Status=running` 且 **pid1 用户 = node** |

### 3.2 容器内回归（名称与脚本中 `check "..."` 一致）

| 名称 | 含义 |
|------|------|
| container running | 容器 running |
| pid1 is node | PID1 为 node |
| restart count zero | `RestartCount==0` |
| cron process | `pgrep cron` |
| tailscaled process | `pgrep tailscaled`（无 tun 则 SKIP） |
| claude / codex / task-master CLI | `--version` |
| cloudcli version | CloudCLI CLI |
| cloudcli HTTP | 容器内 `curl` **127.0.0.1:3001**（默认端口） |
| ccman CLI not dev mode | 无 `[开发模式]`，有语义化版本行 |
| cc-connect real binary | help 含 `Usage:`，**无** `fallback build` |
| gh / tmux / tailscale CLI | 版本 |
| python scientific stack | import pandas/matplotlib/seaborn/scipy |
| claude config generated | `~/.claude/settings.json` |
| codex config generated | `~/.codex/config.toml` |
| codex wire_api responses | `wire_api = "responses"` |
| taskmaster env generated | `global.env` |
| taskmaster provider default | `TASKMASTER_MAIN_PROVIDER=anthropic` |
| user-init executed | `/tmp/user-init-ran` |
| user-init log persisted | log 含 `user-init-ran` |
| background skill log exists | `/var/log/entrypoint-skills.log` |
| **image BOM json** | `/usr/share/doc/coding-agent/bom.json` |
| **image BOM has build metadata** | BOM 含 `coding_agent_version` |
| host→container persistence | `.ci-data/project` → `/home/node/project` |
| container→host persistence | 反向写回宿主机 |
| task-master help as node | `docker exec -u node ... task-master --help` |

通过后才会 **Publish** 到 GHCR（tag 策略见 workflow）。

---

## 四、真机扩展用例（索引）

以下不全部在 `run-all.sh` 中自动化，发布或验收建议在目标机器执行：

- **环境、拉镜像/构建、与 CI 对齐的运行时、`DATA_ROOT` 双向同步、CloudCLI 浏览器、自定义卷、Tailscale、`INSTALL_GO`/`BUILD_ESSENTIAL`、重启/升级、交付记录**：见 **[`MANUAL_REAL_MACHINE_CHECKLIST.md`](./MANUAL_REAL_MACHINE_CHECKLIST.md)**（章节 A～K）。

### 4.1 与锁版本 + BOM 相关的建议手测

| 项 | 命令 / 判定 |
|----|-------------|
| BOM 可读 | `docker exec <容器> cat /usr/share/doc/coding-agent/bom.json` |
| 锁文件在源码中存在 | `docker/npm-required.txt`、`docker/npm-optional.txt`、`docker/python-requirements.txt` |
| 固定镜像制品 | `.env` 中 `DOCKER_IMAGE` 可使用 `...@sha256:...`（见 `UPGRADING.md`） |

---

*维护指引：新增/改名 `tc-*.sh` 内用例或 CI `check()` 时，请同步更新本文档第二节、第三节。*
</think>


<｜tool▁calls▁begin｜><｜tool▁call▁begin｜>
StrReplace
