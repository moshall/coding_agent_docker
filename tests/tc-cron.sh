#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-CRON-01 Dockerfile installs cron" grep -Fq " cron " Dockerfile
run_check "TC-CRON-02 entrypoint starts cron" grep -Fq "starting cron" entrypoint.sh

summary_and_exit
