#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-TOOL-01 npm pins include claude" grep -Fq "@anthropic-ai/claude-code@" docker/npm-required.txt
run_check "TC-TOOL-02 npm pins include codex" grep -Fq "@openai/codex@" docker/npm-required.txt
run_check "TC-TOOL-03 Dockerfile omits gemini-cli" bash -c '! grep -Fq "@google/gemini-cli" Dockerfile'
run_check "TC-TOOL-04 Dockerfile omits opencode-ai" bash -c '! grep -Fq "opencode-ai" Dockerfile'
run_check "TC-TOOL-05 npm pins include task-master" grep -Fq "task-master-ai@" docker/npm-required.txt
run_check "TC-TOOL-06 apt installs gh" grep -Fq "gh tailscale" Dockerfile
run_check "TC-TOOL-07 npm pins include CloudCLI UI" grep -Fq "@siteboon/claude-code-ui@" docker/npm-required.txt
run_check "TC-TOOL-07b Dockerfile installs npm from pin files" grep -Fq "npm-required.txt" Dockerfile
run_check "TC-TOOL-08 entrypoint may start CloudCLI" grep -Fq "maybe_start_cloudcli" entrypoint.sh

summary_and_exit
