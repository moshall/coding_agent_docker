# 真机测试用例清单（Coding Agent Docker）

**完整回归总表**（含全部 `TC-*` 静态编号 + CI 门闸与检查名）：[`REGRESSION_FULL.md`](./REGRESSION_FULL.md)。

在真机上按顺序执行；**先跑 A**，再根据你的部署方式选 **B 或 C**，最后按需勾 **D～K**。  
（与 `.github/workflows/build-push.yml` 中容器就绪后的检查对齐的条目在 **D.2** 标注了「≈CI」。）

---

## A. 仓库静态回归（无需已启动容器）

在**已克隆**的仓库根目录执行：

```bash
bash tests/run-all.sh
```

预期：`All regression scripts completed`，且各 `tests/tc-*.sh` 均为 `pass`。

> 覆盖：Compose 单卷、持久化链接、端口变量、CloudCLI / ccman / cc-connect、skills、Tailscale 设备声明、文档与 workflow 约定等（约 **TC-SMOKE / TC-BUILD / TC-TOOL / …** 全套）。

---

## B. 环境前提（真机一次性确认）

| 序号 | 检查项 | 说明 |
|------|--------|------|
| B-1 | Docker + Compose v2 | `docker version`、`docker compose version` |
| B-2 | `/dev/net/tun` | 存在且容器可访问（Compose 已 `devices` 映射） |
| B-3 | `.env` | 自 `.env.example` 复制；至少测试用 key 可填占位（视你要测的 CLI） |
| B-4 | `DATA_ROOT` 磁盘 | 宿主机目录可写、空间充足 |

---

## C. 镜像来源（二选一或都测）

| 序号 | 场景 | 命令要点 |
|------|------|----------|
| C-1 | **拉取线上镜像** | `docker compose pull` 或 `docker pull ghcr.io/moshall/coding_agent_docker:latest` |
| C-2 | **源码构建** | `docker compose -f docker-compose.dev.yml build --no-cache`（真机若 export 卡住属宿主机 Docker 问题，与用例分开记） |

---

## D. 编排启动与「与 CI 同级」运行时检查

### D.1 启动

| 序号 | 检查项 | 说明 |
|------|--------|------|
| D-1 | `docker compose config` | 无语法/插值错误 |
| D-1b | `up -d` | 容器名与 `CONTAINER_NAME` 一致（默认 `coding-agent`） |
| D-1c | 就绪 | `State.Status=running`；**pid 1 用户为 `node`**（≈CI） |

### D.2 进程与服务（≈CI）

> 将下文 `coding-agent` 换为你的容器名。  

| 序号 | 检查项 | 命令或判定 |
|------|--------|------------|
| D-2.1 | 运行中 | `docker inspect coding-agent --format '{{.State.Status}}'` → `running` |
| D-2.2 | pid1 为 node | `docker exec coding-agent ps -o user= -p 1` → `node` |
| D-2.3 | 重启次数 | `RestartCount` 为 `0`（刚启动场景） |
| D-2.4 | cron | `docker exec coding-agent pgrep -x cron` |
| D-2.5 | tailscaled | `docker exec coding-agent pgrep -x tailscaled`（无 tun 时可记 SKIP） |
| D-2.6 | claude | `docker exec coding-agent claude --version` |
| D-2.7 | codex | `docker exec coding-agent codex --version` |
| D-2.8 | task-master | `docker exec coding-agent task-master --version` |
| D-2.9 | cloudcli | `docker exec coding-agent cloudcli version` |
| D-2.10 | CloudCLI HTTP | 容器内 `curl -fsS http://127.0.0.1:${CLOUDCLI_PORT:-3001}/`（默认 3001；≈CI） |
| D-2.11 | ccman 非开发模式 | `ccman --version` 输出无 `[开发模式]`，含 `x.y.z` 版本行 |
| D-2.12 | cc-connect | `cc-connect --help` 含 `Usage:`，且**无** `fallback build` |
| D-2.13 | gh | `gh --version` |
| D-2.14 | tmux | `tmux -V` |
| D-2.15 | tailscale CLI | `tailscale version` |
| D-2.16 | Python 科学栈 | 容器内 `python3 -c "import pandas, matplotlib, seaborn, scipy; print('ok')"` |

### D.3 配置文件生成（≈CI）

| 序号 | 检查项 | 路径 / 内容 |
|------|--------|----------------|
| D-3.1 | Claude | `/home/node/.claude/settings.json` 存在 |
| D-3.2 | Codex | `/home/node/.codex/config.toml` 存在 |
| D-3.3 | Codex wire_api | `config.toml` 含 `wire_api = "responses"` |
| D-3.4 | Task Master | `/home/node/.task-master/global.env` 存在 |
| D-3.5 | Task Master provider | `global.env` 含 `TASKMASTER_MAIN_PROVIDER=anthropic`（若 .env 未改默认） |
| D-3.6 | user-init（若配置） | `${DATA_ROOT}/user-init.sh` 执行后你在脚本里 touch 的标记文件存在 |
| D-3.7 | skill 后台日志 | `/var/log/entrypoint-skills.log` 存在 |
| D-3.8 | 镜像 BOM | `test -f /usr/share/doc/coding-agent/bom.json`；或 `echo "$CODING_AGENT_BOM_PATH"` |

### D.4 权限冒烟（≈CI）

| 序号 | 检查项 | 命令 |
|------|--------|------|
| D-4.1 | task-master 以 node | `docker exec -u node coding-agent bash -c 'task-master --help >/dev/null'` |

---

## E. DATA_ROOT 持久化（≈CI 双向同步）

将 `DATA_ROOT` 换成真机路径（与 `.env` 一致）。

| 序号 | 检查项 | 操作 |
|------|--------|------|
| E-1 | 宿主机 → 容器 | 在宿主机 `${DATA_ROOT}/project/host-sync.txt` 写入 `host-<timestamp>`；容器内 `cat /home/node/project/host-sync.txt` 一致 |
| E-2 | 容器 → 宿主机 | 容器内 `echo container-... > /home/node/project/container-sync.txt`；宿主机同路径文件可见 |
| E-3 | 目录结构 | 存在 `project/`、`config/`、`software/` 下 entrypoint 创建的子树（首次启动后） |

---

## F. CloudCLI（claudecodeui）与端口

| 序号 | 检查项 | 说明 |
|------|--------|------|
| F-1 | 映射 | 宿主机 `PORT_CLOUDCLI`（默认 3001）→ 容器 `CLOUDCLI_PORT`（默认 3001） |
| F-2 | 浏览器 | `http://<真机IP>:<PORT_CLOUDCLI>/` 可打开（防火墙放行） |
| F-3 | 关闭 CloudCLI | `.env` 设 `CLOUDCLI_ENABLE=false` 重启后，进程不应长期占用 3001（按需验证） |
| F-4 | 改端口 | 改 `CLOUDCLI_PORT` 后，Compose 映射右侧与 `-p` 右侧需一致 |

---

## G. 额外宿主机目录挂载（自定义）

| 序号 | 检查项 | 说明 |
|------|--------|------|
| G-1 | 只读/读写 | `compose` 增加 `- /host/path:/mnt/extra:ro` 或读写 |
| G-2 | 容器内可见 | `docker exec ... ls /mnt/extra` |
| G-3 | 权限 | `node` 用户能否读/写符合预期 |

---

## H. Tailscale（可选真网）

| 序号 | 检查项 | 说明 |
|------|--------|------|
| H-1 | 无 authkey | 容器应仍能启动；`tailscaled` 存在 |
| H-2 | 有 authkey | `tailscale status` / ping 虚拟网邻居（依你环境） |

---

## I. 可选运行时开关

| 序号 | 检查项 | 说明 |
|------|--------|------|
| I-1 | `INSTALL_GO_RUNTIME=true` | 启动后 `go version`；标记在 `${DATA_ROOT}/software/bootstrap/` |
| I-2 | `INSTALL_BUILD_ESSENTIAL=true` | `gcc` 等可用；同样有 bootstrap 标记 |
| I-3 | 关闭记忆 | 清 env 且删对应 marker 后不再安装 |

---

## J. 破坏性与升级场景（建议各做一次）

| 序号 | 检查项 | 预期 |
|------|--------|------|
| J-1 | `docker compose restart` | 数据仍在，`settings.json`/project 文件不丢 |
| J-2 | `docker compose down && up -d` | 同卷同 `DATA_ROOT`，配置与项目仍在 |
| J-3 | 换新镜像 tag | 工具版本可能变，`DATA_ROOT` 下配置保留 |

---

## K. 交付记录（真机测完可填）

| 项目 | 内容 |
|------|------|
| 机器 OS / Docker 版本 | |
| 镜像 | pull digest 或 build id |
| DATA_ROOT 路径 | |
| 失败项与日志片段 | |

---

*清单版本：与单卷 `DATA_ROOT`、CloudCLI、当前 `tests/run-all.sh` 与 `build-push.yml` 回归段对齐。*
