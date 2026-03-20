# Upgrade Guide

## Standard Upgrade

```bash
docker compose pull
docker compose down
docker compose up -d
```

Data in `${DATA_ROOT:-/data/coding-agent}` persists across upgrades.

## Rollback

1. Set a previous image tag in `.env`:
```env
DOCKER_IMAGE=your-dockerhub-username/coding-agent:v1.3.0
```
   或使用 digest 锁定某次构建（避免 tag 被覆盖）：
```env
DOCKER_IMAGE=ghcr.io/org/coding_agent@sha256:...
```
2. Restart:
```bash
docker compose down
docker compose up -d
```

## Pinned tool versions (maintainers)

镜像内 **npm / pip** 版本由仓库中的锁文件决定：

- `docker/npm-required.txt`、`docker/npm-optional.txt`
- `docker/python-requirements.txt`

升级上游 CLI 时：编辑上述文件中的版本号 → 本地 `docker compose build` 验证 → 提交并打 **新的镜像 tag**，便于用户固定拉取。

构建后可在容器内查看实际装入的版本：`cat /usr/share/doc/coding-agent/bom.json`（亦见环境变量 `CODING_AGENT_BOM_PATH`）。

## Post-Upgrade Checks

```bash
docker compose exec coding-agent bash -lc "claude --version && codex --version && task-master --version"
```
