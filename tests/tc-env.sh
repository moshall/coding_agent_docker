#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-ENV-01 env template exists" test -f .env.example
run_check "TC-ENV-02 includes Task Master provider" grep -Fq "TASKMASTER_MAIN_PROVIDER" .env.example
run_check "TC-ENV-03 codex uses responses API" grep -Fq "wire_api = \"responses\"" entrypoint.sh

summary_and_exit
