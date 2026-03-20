# 1Panel 部署模板

1Panel **没有单独的「应用商店 JSON 模板」**对外标准；实际就是在你指定的目录里放 **`docker-compose.yml` + `.env`**，由面板调用 Docker Compose。本目录提供一套 **按 1Panel 习惯路径做过默认值的编排**，方便「整夹上传 / 复制」使用。

## 包含文件

| 文件 | 说明 |
|------|------|
| [docker-compose.yml](./docker-compose.yml) | 独立可用；含 `version: "3.8"`、`name:`，部分面板校验更稳定；**默认 `DATA_ROOT` 为 `/opt/1panel/apps/coding_agent_docker`** |
| [.env.example](./.env.example) | 复制为 `.env` 后填写 API Key；路径与 compose 默认一致 |

与仓库根目录 `docker-compose.yml` 的差异主要是：**默认数据目录**、顶部 **version/name**、**可选 OpenClaw 挂载注释**。逻辑一致；主文件更新后我们会尽量同步本目录（见 compose 内注释）。

## 推荐目录（示例）

```text
/opt/1panel/docker/compose/coding_agent_docker/
├── docker-compose.yml   # 使用本目录提供的文件
└── .env                 # 从 .env.example 复制
```

宿主机数据目录（需提前创建并赋权给容器内 `node`，uid **1000**）：

```bash
sudo mkdir -p /opt/1panel/apps/coding_agent_docker
sudo chown -R 1000:1000 /opt/1panel/apps/coding_agent_docker
```

## 在 1Panel 里怎么接

1. **文件**：把 `docker-compose.yml`、`.env` 放到同一目录（路径可与上表不同，但二者必须同目录）。
2. **面板**：打开 **容器 → Compose / 编排**（名称因版本略不同）→ **创建 / 导入**，选择该目录或指定 `docker-compose.yml` 路径。
3. **不要用 empty 密钥报错**：本仓库 compose 已使用 `${VAR:-}`，未填 Key 时不应再刷「variable is not set」告警；若面板仍失败，到该目录 SSH 执行 `docker compose config` 看真实错误。
4. **云防火墙 / 安全组**：放行 `PORT_CLOUDCLI`（默认 **3001**）等你映射的端口。

## OpenClaw 等同路径挂载

编辑本目录 `docker-compose.yml`，在 `volumes` 下取消注释并修改宿主机路径，例如：

```yaml
- "/opt/1panel/apps/openclaw_260205:${DATA_ROOT:-/opt/1panel/apps/coding_agent_docker}/project/openclaw"
```

宿主机目录需对 **1000:1000** 可写，见主 README 持久化小节。

## 仍想通用部署？

不限定 1Panel 时，可直接用仓库根目录的 [docker-compose.yml](../../docker-compose.yml) 与 [.env.example](../../.env.example)（默认 `DATA_ROOT=/data/coding-agent`）。
