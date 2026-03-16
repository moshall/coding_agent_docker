# Contributing

## Development Setup

1. Clone repository.
2. Copy `.env.example` to `.env`.
3. Fill required API keys.
4. Build and start dev container:

```bash
docker compose -f docker-compose.dev.yml build
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

## Workflow

1. Create a branch.
2. Make changes.
3. Run tests:
```bash
bash tests/run-all.sh
```
4. Commit with descriptive message.
5. Open a PR.

## Testing

- Full suite: `bash tests/run-all.sh`
- Individual script: `bash tests/tc-build.sh`

## Release

1. Update changelog.
2. Tag release: `git tag vX.Y.Z`
3. Push branch and tags.

## Style

- Bash scripts should pass `bash -n`.
- Prefer idempotent startup logic.
- Add regression checks for behavior changes.
