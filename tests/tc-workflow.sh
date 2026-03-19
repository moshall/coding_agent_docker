#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-WORKFLOW-01 workflow verifies cc-connect help output" grep -Fq 'cc-connect --help' .github/workflows/build-push.yml
run_check "TC-WORKFLOW-02 workflow rejects cc-connect fallback binary" grep -Fq 'fallback build' .github/workflows/build-push.yml
run_check "TC-WORKFLOW-03 workflow rejects ccman dev mode" grep -Fq '\\[开发模式\\]' .github/workflows/build-push.yml

summary_and_exit
