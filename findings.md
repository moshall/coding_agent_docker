# Findings & Decisions

## 2026-03-19 Remote Validation Findings

### Requirements
- User asked for real VPS validation on Ubuntu 22.04 covering native Docker, 1Panel, GitHub auto-build usability, and published-image usability on Linux.

### Findings So Far
- Clean VPS currently has no Docker or Docker Compose installed.
- Current local workspace contains uncommitted changes that matter for validation, including:
  - optional runtime package persistence
  - `ccman` wrapper/persistence changes
  - corrected `cc-connect` source repository
- GitHub Actions workflow already performs a no-cache source build on `docker-compose.dev.yml`, starts the container, and runs a broad runtime smoke/regression set.
- A real defect was confirmed from user runtime evidence: `cc-connect` was previously built from the wrong repo (`openclaw/cc-connect`), causing fallback binary output. This is now corrected locally to `chenhg5/cc-connect`.

### Additional Verified Findings
- VPS baseline after setup:
  - Docker Engine `29.3.0`
  - Docker Compose `v5.1.0`
  - 1Panel agent installed and active on Ubuntu 22.04.1 LTS
- 1Panel-style compose deployment under `/opt/1panel/docker/compose/coding_agent_paneltest` works with the locally fixed source image path conventions:
  - container reaches `pid1=node`
  - config files are generated under persisted bind mounts
  - project directory host/container bidirectional persistence works
  - `cc-connect --help` shows the real binary help output instead of fallback text
- Fresh pull of public `ghcr.io/moshall/coding_agent_docker:latest` on 2026-03-19 still shows three concrete regressions:
  - `ccman --version` still reports dev-mode paths under `/tmp/ccman-dev/...`
  - `cc-connect --help` still prints `cc-connect fallback build`
  - `gemini --version` still emits the `projects.json.tmp -> projects.json` ENOENT error on first clean run
- Root cause investigation for the Gemini issue:
  - Reproduces reliably when `HOME` points to a brand-new empty directory
  - Not caused by permissions or 1Panel pathing
  - Pre-creating `~/.gemini/projects.json` with `{"projects":{}}` avoids the error cleanly
- GitHub Actions state checked via GitHub API on 2026-03-19:
  - latest workflow run `#11` completed successfully at `2026-03-19T05:21:32Z`
  - scheduled run `#8` on `2026-03-18T23:46:24Z` also succeeded
  - an earlier scheduled run `#6` failed in the `Regression checks` step
- Native source build on this Ubuntu 22.04 VPS remains blocked by the host's Docker export path, even after slimming changes:
  - `docker compose build --no-cache` previously stalled at `exporting to image` / `unpacking`
  - `docker build --no-cache` with legacy builder stalled on image layer commit after npm layers
  - `docker buildx build --output type=docker,dest=...tar` also stalled at `exporting layers`
  - This points to a host-specific Docker 29.3.0 image export/commit issue, not a single Dockerfile command failure
- Build-slimming investigation found a major contributor:
  - baking `openclaw/skills` (~200k files) into the image during build caused extremely heavy layer commits
  - local code has now been changed to defer `superpowers` and `openclaw/skills` repo sync to startup background bootstrap instead of image build
- Follow-up verification on a freshly reinstalled Ubuntu 24.04.2 LTS host (same VPS, same Docker major version) showed:
  - native `docker build --no-cache -t coding-agent:dev .` completed successfully
  - export phase completed instead of hanging (`exporting layers` and `unpacking` both finished)
  - locally built image inspect size was about `1.87 GB`
  - fresh runtime validation for the source-built image passed for `claude`, `codex`, `task-master`, `ccman`, `cc-connect`, `gemini`, and project persistence
- GitHub Actions run `#12` for commit `17d0271` completed successfully on 2026-03-19 and published a corrected `ghcr.io/moshall/coding_agent_docker:latest`
- Fresh pull/run verification of the new GHCR `latest` on Ubuntu 24.04 passed:
  - `ccman --version` no longer showed dev-mode paths
  - `cc-connect --help` showed the real application help output
  - `gemini --version` completed cleanly without the prior ENOENT message
  - pulled image inspect size was also about `1.87 GB`

### Local Fixes Added During Validation
- Seed `/home/node/.gemini/projects.json` in `entrypoint.sh` to prevent Gemini first-run ENOENT noise.
- Strengthened `.github/workflows/build-push.yml` so CI now checks:
  - `cc-connect --help` must not show fallback output
  - `ccman --version` must not report dev-mode paths
- Added regression coverage:
  - `tests/tc-gemini.sh`
  - `tests/tc-workflow.sh`
  - extra build/skills checks for deferred repo bootstrap

### Validation Targets
1. Source build on Ubuntu 22.04 using current workspace contents
2. Pull/run of published GHCR image on Ubuntu 22.04
3. 1Panel deployment behavior using the project compose model
4. Gap analysis between real-world results and current CI workflow

## Requirements
- User asked to initialize and use Task Master in the current project.
- User then asked to implement the decomposed PRD functionality.
- PRD v1.4 defines a Docker-based coding-agent distribution with multi-tool CLI support, persistent volume model, idempotent entrypoint behavior, docs, CI, and tests.

## Research Findings
- `task-master` CLI is installed locally and working (version 0.43.0).
- Correct command is `task-master` (not `taskmaster` or `taskmaskter`).
- PRD parse succeeded with provider `claude-code` and model `sonnet` and generated 10 tasks.
- Repo currently started from minimal files and required full project bootstrap.
- `docker compose config` and `docker compose -f docker-compose.dev.yml config` both parse successfully.
- Compose prints expected warnings when API key env vars are unset and notes `version` is obsolete.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Use `node:22-bookworm` final image with a separate Go builder stage | Matches PRD and keeps final image cleaner |
| Keep entrypoint root-only bootstrap then `gosu node` execution | Required for permission fixes and Claude root restriction |
| Provide `docker-compose.yml` and `docker-compose.dev.yml` | Supports production pull and local build workflows |
| Add explicit regression scripts under `tests/` | Aligns with PRD section for categorized TC checks |
| Validate implementation with static regression checks by default | Faster feedback and no dependency on external credentials during local verification |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Literal `$@` check in smoke test expanded unexpectedly | Switched to single-quoted grep pattern and reran suite |
| `gemini --version` emitted first-run registry ENOENT on clean HOME | Verified root cause in Gemini initialization and mitigated by seeding `projects.json` in entrypoint |
| Ubuntu 22.04 VPS source builds stalled during Docker image export/commit | Reduced build-time layer weight locally and confirmed remaining problem is host Docker export path rather than a failing Dockerfile command |

## Resources
- `coding-agent-prd-v1.4.md`
- `.taskmaster/tasks/tasks.json`
- Task Master CLI help output in local terminal

## Visual/Browser Findings
- No browser/image inputs were used in this implementation phase.

---
*Update this file after every 2 view/browser/search operations*
*This prevents visual information from being lost*
