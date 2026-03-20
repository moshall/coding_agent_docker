# Task Plan: Coding Agent Docker PRD v1.4 Implementation

## Active Task: 2026-03-19 Ubuntu/1Panel Remote Validation

### Goal
Validate the current Docker project on a clean Ubuntu 22.04 VPS across three paths: native Docker source build/run, published-image pull/run, and 1Panel deployment behavior, then assess whether the GitHub Actions workflow is sufficient and accurate.

### Current Phase
Workflow assessment and reporting

### Validation Phases

#### Phase A: Local audit before remote execution
- [x] Re-read compose files, workflow, and current uncommitted changes
- [x] Identify required remote checks for source build, pulled image, and panel deployment
- **Status:** complete

#### Phase B: Remote native Docker validation
- [x] Install Docker / Compose on clean Ubuntu 22.04
- [x] Upload current workspace state to VPS
- [x] Run pull-based validation against published image
- [x] Run no-cache source build attempts and capture exact failure mode
- **Status:** complete

#### Phase C: Remote 1Panel validation
- [x] Install 1Panel and confirm Docker integration
- [x] Import or recreate compose app under panel-managed paths
- [x] Validate runtime behavior, persistence, and operator workflow
- **Status:** complete

#### Phase D: Workflow equivalence assessment
- [x] Compare remote results against `.github/workflows/build-push.yml`
- [x] Identify missing checks and environment-specific gaps
- [x] Summarize pass/fail findings and remaining risks
- **Status:** complete

### Current Decisions
| Decision | Rationale |
|----------|-----------|
| Validate current workspace state on VPS instead of only GitHub HEAD | Local fixes are uncommitted and need real-world verification before release |
| Test both source-built image and published GHCR image | Covers build correctness and end-user pull usability separately |
| Treat 1Panel as a distinct deployment surface | Panel-managed compose paths and exec defaults can differ from native Docker |

### New Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| Published/runtime `cc-connect` printed `fallback build` | 1 | Traced to wrong source repo in Dockerfile and corrected to `chenhg5/cc-connect` before remote retest |
| Public GHCR image still showed `ccman` dev-mode paths | 1 | Confirmed published image is behind local uncommitted wrapper fix; strengthened local workflow regression to catch it |
| Gemini first-run registry write emitted ENOENT | 1 | Reproduced on clean HOME and fixed locally by seeding `~/.gemini/projects.json` in entrypoint |
| Ubuntu 22.04 VPS source build stalled in Docker export/commit path across three build methods | 1 | Reduced build-time repo payload locally and concluded remaining blocker is host Docker export path, not a single Dockerfile step |
| Need to re-validate on a fresh system after release push | 1 | Re-ran end-to-end on Ubuntu 24.04.2, where source build and fresh GHCR pull/run both succeeded |

## Goal
Implement the Coding Agent Docker project from the PRD and generated Task Master tasks, including container build, runtime entrypoint, compose setup, docs, CI workflow, and regression test scripts.

## Current Phase
Phase 5

## Phases

### Phase 1: Requirements & Discovery
- [x] Understand user intent
- [x] Identify constraints and requirements
- [x] Document findings in findings.md
- **Status:** complete

### Phase 2: Planning & Structure
- [x] Define technical approach
- [x] Create project structure
- [x] Document decisions with rationale
- **Status:** complete

### Phase 3: Implementation
- [x] Write failing tests first for key runtime behavior
- [x] Implement Dockerfile, entrypoint, compose, env templates
- [x] Implement docs and metadata files
- [x] Implement CI workflow and regression scripts
- **Status:** complete

### Phase 4: Testing & Verification
- [x] Run test suite and script syntax checks
- [x] Verify compose config parses
- [x] Record test results in progress.md
- **Status:** complete

### Phase 5: Delivery
- [x] Review all deliverables
- [x] Summarize what was implemented and limitations
- [x] Deliver implementation details to user
- **Status:** complete

## Key Questions
1. Should we implement the full task set now? (Assumption: yes, user asked to implement after decomposition)
2. Should we prioritize runnable defaults over strict external tool availability? (Assumption: yes, use defensive install fallbacks where needed)

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Implement all 10 generated Task Master tasks in one pass | Matches user request to continue immediately after decomposition |
| Use shell-based regression tests plus static checks | Suitable for Docker-centric project and CI portability |
| Use idempotent entrypoint generation logic | Required to preserve persisted auth/config across restarts |
| Keep optional package/skill installation tolerant in entrypoint and Dockerfile | Avoid container hard-failure on non-critical upstream package availability |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `tests/tc-smoke.sh` failed matching `exec gosu node \"$@\"` | 1 | Fixed quoting to match literal `$@` and reran full suite successfully |

## Notes
- Follow TDD spirit: write failing tests before implementation for script behavior
- Keep files ASCII-only where possible
- Verify before completion with concrete command outputs
