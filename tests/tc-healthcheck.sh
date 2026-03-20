#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-HEALTH-01 healthcheck script exists" test -f scripts/healthcheck.sh
run_check "TC-HEALTH-02 script checks container running state" grep -Fq "container running" scripts/healthcheck.sh
run_check "TC-HEALTH-03 script checks cron process" grep -Fq "cron process" scripts/healthcheck.sh
run_check "TC-HEALTH-04 script checks cloudcli HTTP readiness" grep -Fq "cloudcli HTTP" scripts/healthcheck.sh
run_check "TC-HEALTH-05 script supports tailscaled optional check" grep -Fq "tailscaled process" scripts/healthcheck.sh

summary_and_exit
