#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-GEMINI-01 entrypoint defines Gemini project registry path" grep -Fq 'GEMINI_PROJECT_REGISTRY="/home/node/.gemini/projects.json"' entrypoint.sh
run_check "TC-GEMINI-02 entrypoint seeds Gemini project registry" grep -Fq '"projects": {}' entrypoint.sh

summary_and_exit
