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
2. Restart:
```bash
docker compose down
docker compose up -d
```

## Post-Upgrade Checks

```bash
docker compose exec coding-agent bash -lc "claude --version && codex --version && gemini --version"
```
