#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-PORT-01 cc-connect port" grep -Fq "PORT_CC_CONNECT" .env.example
run_check "TC-PORT-02 ralph port" grep -Fq "PORT_RALPH" .env.example
run_check "TC-PORT-03 dev port" grep -Fq "PORT_DEV" .env.example
run_check "TC-PORT-04 CloudCLI port" grep -Fq "PORT_CLOUDCLI" .env.example

summary_and_exit
