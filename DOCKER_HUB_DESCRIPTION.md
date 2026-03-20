# Coding Agent - All-in-One AI Development Container

A Docker image that bundles multiple coding assistants with persistent auth/config and project storage.

## Quick Start

```bash
cp .env.example .env
# fill keys
docker compose up -d
docker compose exec coding-agent bash
```

## Included

- Claude Code
- Codex
- Task Master
- cc-connect, ccman, CloudCLI (claudecodeui)
- Node/Python toolchain, with optional Go runtime bootstrap

## Persistence

Single host mount: `${DATA_ROOT}` (default `/data/coding-agent`) maps to the same path in the container. Inside it:

1. **`project/`** — code / workspace (`/home/node/project`，兼容旧目录 `projects`）
2. **`config/`** — tool configs（`.claude`、`.codex`、Task Master 等由 entrypoint 链入）
3. **`software/`** — 运行时与缓存（Tailscale 状态、`go`、cron、bootstrap 标记等）

Extra bind mounts（例如与其它栈共享同一宿主机路径）由用户在 Compose 中自行添加。

Tooling versions are pinned at build via `docker/npm-*.txt` and `docker/python-requirements.txt`; see `bom.json` inside the image (`CODING_AGENT_BOM_PATH`).
