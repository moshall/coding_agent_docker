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
- Gemini CLI
- OpenCode
- Task Master
- cc-connect, ccman
- Node/Python/Go/Rust toolchain

## Persistence

1. Config layer (`/data/coding-agent/config`)
2. Project layer (`/data/coding-agent/projects`)
3. Optional extra mounts (`MOUNT_OPENCLAW`, `MOUNT_EXTRA_*`)
