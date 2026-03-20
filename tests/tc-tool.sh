#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-TOOL-01 npm pins include claude" grep -Fq "@anthropic-ai/claude-code@" docker/npm-required.txt
run_check "TC-TOOL-02 npm pins include codex" grep -Fq "@openai/codex@" docker/npm-required.txt
run_check "TC-TOOL-03 Dockerfile omits gemini-cli" bash -c '! grep -Fq "@google/gemini-cli" Dockerfile'
run_check "TC-TOOL-04 Dockerfile omits opencode-ai" bash -c '! grep -Fq "opencode-ai" Dockerfile'
run_check "TC-TOOL-05 npm pins include task-master" grep -Fq "task-master-ai@" docker/npm-required.txt
run_check "TC-TOOL-06 Dockerfile supports GH version pin" grep -Fq "ARG GH_VERSION=" Dockerfile
run_check "TC-TOOL-07 npm pins include CloudCLI UI" grep -Fq "@siteboon/claude-code-ui@" docker/npm-required.txt
run_check "TC-TOOL-07b Dockerfile installs npm from pin files" grep -Fq "npm-required.txt" Dockerfile
run_check "TC-TOOL-08 entrypoint may start CloudCLI" grep -Fq "maybe_start_cloudcli" entrypoint.sh
run_check "TC-TOOL-09 cloudcli wrapper script exists" test -f cloudcli-wrapper.sh
run_check "TC-TOOL-10 Dockerfile installs cloudcli wrapper" grep -Fq "cloudcli-wrapper.sh" Dockerfile
run_check "TC-TOOL-11 entrypoint exports CloudCLI workspace root" grep -Fq 'WORKSPACES_ROOT="${workspaces_root}"' entrypoint.sh
run_check "TC-TOOL-12 cloudcli wrapper has python socket fallback check" grep -Fq "connect_ex((\"127.0.0.1\", port))" cloudcli-wrapper.sh

summary_and_exit
