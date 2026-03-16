#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-TOOL-01 npm installs claude" grep -Fq "@anthropic-ai/claude-code" Dockerfile
run_check "TC-TOOL-02 npm installs codex" grep -Fq "@openai/codex" Dockerfile
run_check "TC-TOOL-03 npm installs gemini" grep -Fq "@google/gemini-cli" Dockerfile
run_check "TC-TOOL-04 npm installs task-master" grep -Fq "task-master-ai" Dockerfile
run_check "TC-TOOL-05 apt installs gh" grep -Fq "gh tailscale" Dockerfile

summary_and_exit
