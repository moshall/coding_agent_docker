#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-ENV-01 env template exists" test -f .env.example
run_check "TC-ENV-02 includes Task Master provider" grep -Fq "TASKMASTER_MAIN_PROVIDER" .env.example
run_check "TC-ENV-03 codex uses responses API" grep -Fq "wire_api = \"responses\"" entrypoint.sh
run_check "TC-ENV-04 includes optional Go runtime switch" grep -Fq "INSTALL_GO_RUNTIME" .env.example
run_check "TC-ENV-05 includes optional build-essential switch" grep -Fq "INSTALL_BUILD_ESSENTIAL" .env.example
run_check "TC-ENV-06 includes CloudCLI workspace root switch" grep -Fq "CLOUDCLI_WORKSPACES_ROOT" .env.example
run_check "TC-ENV-07 includes Codex legacy landlock compatibility switch" grep -Fq "CODEX_USE_LEGACY_LANDLOCK" .env.example

summary_and_exit
