#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-MOUNT-01 compose omits MOUNT_* env wiring" bash -c '! grep -qE "MOUNT_(OPENCLAW|EXTRA)" docker-compose.yml'
run_check "TC-MOUNT-02 entrypoint supports legacy host projects dir" grep -Fq '${DATA_ROOT}/projects' entrypoint.sh
run_check "TC-MOUNT-03 README mentions user-defined extra volumes" grep -Fq "自行" README.md

summary_and_exit
