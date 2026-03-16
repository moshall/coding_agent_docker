# Changelog

All notable changes to this project are documented in this file.

## [1.4.0] - 2026-03-13

### Added
- Multi-stage Dockerfile with Go builder and Node runtime
- Root bootstrap entrypoint with `gosu` switch to node
- Three-layer Docker Compose volume model
- `.env.example` and `user-init.sh.example`
- CI workflow for multi-arch build and push
- Regression test scripts under `tests/`
- Project docs and release docs
