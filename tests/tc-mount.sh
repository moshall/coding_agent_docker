#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-MOUNT-01 optional OpenClaw mount" grep -Fq "MOUNT_OPENCLAW" docker-compose.yml
run_check "TC-MOUNT-02 optional workspace-1 mount" grep -Fq "MOUNT_EXTRA_1" docker-compose.yml
run_check "TC-MOUNT-03 optional workspace-2 mount" grep -Fq "MOUNT_EXTRA_2" docker-compose.yml
run_check "TC-MOUNT-04 optional workspace-3 mount" grep -Fq "MOUNT_EXTRA_3" docker-compose.yml

summary_and_exit
