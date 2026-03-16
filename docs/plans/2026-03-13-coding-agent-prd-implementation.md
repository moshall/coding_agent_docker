# Coding Agent PRD v1.4 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the full Coding Agent Docker project from PRD v1.4 and Task Master task decomposition in this repository.

**Architecture:** Use a multi-stage Docker build to compile Go artifacts separately and keep runtime image focused on Node-based tooling. Use an idempotent root entrypoint for bootstrap and configuration generation, then switch to `node` with `gosu` for normal execution. Persist all user state through a three-layer bind mount strategy in Docker Compose.

**Tech Stack:** Docker, Bash, Debian apt packages, npm global CLIs, GitHub Actions, shell-based regression tests

---

### Task 1: Create failing tests first (TDD Red)

**Files:**
- Create: `tests/lib/assert.sh`
- Create: `tests/tc-smoke.sh`
- Create: `tests/run-all.sh`

**Step 1: Write failing tests**
- Add smoke checks for existence/expected structure of `Dockerfile`, `entrypoint.sh`, `docker-compose.yml`, and `.env.example`.

**Step 2: Run tests to verify fail**
Run: `bash tests/run-all.sh`
Expected: FAIL due to missing implementation files.

**Step 3: Implement minimal test harness refinements**
- Keep helper assertions simple and portable.

**Step 4: Re-run tests**
Run: `bash tests/run-all.sh`
Expected: still FAIL until implementation is added.

### Task 2: Implement core runtime files

**Files:**
- Create: `Dockerfile`
- Create: `entrypoint.sh`
- Create: `docker-compose.yml`
- Create: `docker-compose.dev.yml`
- Create: `.env.example`
- Create: `user-init.sh.example`

**Step 1: Implement Dockerfile**
- Multi-stage Go builder + Node runtime.
- Install required apt packages, language toolchains, and CLI tools.

**Step 2: Implement entrypoint bootstrap**
- Root check, directory bootstrap, service startup, config generation, skill/user hook handling, gosu handoff.

**Step 3: Implement compose + env templates**
- Three-layer volume model, ports, env mapping, tailscale capabilities.

**Step 4: Re-run smoke tests**
Run: `bash tests/run-all.sh`
Expected: PASS for core file and structure checks.

### Task 3: Implement docs and metadata

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Create: `CONTRIBUTING.md`
- Create: `CHANGELOG.md`
- Create: `SECURITY.md`
- Create: `CODE_OF_CONDUCT.md`
- Create: `RELEASE_NOTES.md`
- Create: `UPGRADING.md`
- Create: `DOCKER_HUB_DESCRIPTION.md`

**Step 1: Write user-facing setup and operations docs**
- Include quick start, persistence model, advanced usage, troubleshooting.

**Step 2: Write collaboration and policy docs**
- Contribution guide, changelog seed, security disclosure, conduct.

**Step 3: Extend tests for docs presence**
- Add checks in test scripts that required docs exist.

### Task 4: Implement CI/CD and full regression scripts

**Files:**
- Create: `.github/workflows/build-push.yml`
- Create: `tests/lib/helpers.sh`
- Create: `tests/tc-build.sh`
- Create: `tests/tc-user.sh`
- Create: `tests/tc-tool.sh`
- Create: `tests/tc-persist.sh`
- Create: `tests/tc-mount.sh`
- Create: `tests/tc-userinit.sh`
- Create: `tests/tc-env.sh`
- Create: `tests/tc-cron.sh`
- Create: `tests/tc-tmux.sh`
- Create: `tests/tc-tailscale.sh`
- Create: `tests/tc-skills.sh`
- Create: `tests/tc-port.sh`
- Create: `tests/tc-release.sh`

**Step 1: Add workflow for multi-arch build and publish**
- Buildx, QEMU, Docker metadata tags, cache, summary output.

**Step 2: Add categorized regression scripts**
- Implement command-based checks and skip logic where environment preconditions are absent.

**Step 3: Wire run-all orchestrator**
- Run tests in a stable order with clear pass/fail output.

### Task 5: Verify and finalize

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Verification commands**
Run:
- `bash tests/run-all.sh`
- `bash -n entrypoint.sh`
- `bash -n tests/run-all.sh`
- `docker compose config` (if Docker daemon available)

**Step 2: Record results**
- Update progress and findings with outcomes and gaps.

**Step 3: Final delivery summary**
- Summarize implemented files, validated behaviors, and follow-up recommendations.
