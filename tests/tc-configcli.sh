#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-CONFIGCLI-01 config cli script exists" test -f codingagentconfig.sh
run_check "TC-CONFIGCLI-02 Dockerfile installs codingagentconfig command" grep -Fq "/usr/local/bin/codingagentconfig" Dockerfile
run_check "TC-CONFIGCLI-03 menu has quick configure provider entry" grep -Fq "Quick configure provider" codingagentconfig.sh
run_check "TC-CONFIGCLI-04 menu can launch ccman" grep -Fq "ccman" codingagentconfig.sh
run_check "TC-CONFIGCLI-05 update menu includes claudecodeui" grep -Fq "claudecodeui" codingagentconfig.sh
run_check "TC-CONFIGCLI-06 workspace creation uses cloudcli default workspace path" grep -Fq 'CLOUDCLI_DEFAULT_WORKSPACE_PATH' codingagentconfig.sh
run_check "TC-CONFIGCLI-07 workspace name has english-only validation" grep -Fq '^[A-Za-z][A-Za-z0-9_-]*$' codingagentconfig.sh
run_check "TC-CONFIGCLI-08 menu has health status entry" grep -Fq "Health status" codingagentconfig.sh
run_check "TC-CONFIGCLI-09 health check validates cron process" grep -Fq "cron process" codingagentconfig.sh
run_check "TC-CONFIGCLI-10 health check validates cloudcli HTTP" grep -Fq "cloudcli HTTP" codingagentconfig.sh
run_check "TC-CONFIGCLI-11 menu has cc-connect quick bind entry" grep -Fq "cc-connect quick bind" codingagentconfig.sh
run_check "TC-CONFIGCLI-12 quick bind writes cc-connect config path" grep -Fq ".cc-connect/config.toml" codingagentconfig.sh
run_check "TC-CONFIGCLI-13 quick bind supports Telegram" grep -Fq 'platform_type="telegram"' codingagentconfig.sh
run_check "TC-CONFIGCLI-14 quick bind supports Discord" grep -Fq 'platform_type="discord"' codingagentconfig.sh
run_check "TC-CONFIGCLI-15 quick bind supports Feishu" grep -Fq 'platform_type="feishu"' codingagentconfig.sh
run_check "TC-CONFIGCLI-16 menu has cc-connect self-check entry" grep -Fq "cc-connect connection self-check" codingagentconfig.sh
run_check "TC-CONFIGCLI-17 self-check validates cc-connect config path" grep -Fq "cc_connect_config_path" codingagentconfig.sh
run_check "TC-CONFIGCLI-18 self-check validates credentials fields" grep -Fq "Credentials:" codingagentconfig.sh
run_check "TC-CONFIGCLI-19 self-check validates cc-connect process" grep -Fq "cc-connect process" codingagentconfig.sh
run_check "TC-CONFIGCLI-20 self-check validates cc-connect port listening" grep -Fq "cc-connect listening" codingagentconfig.sh

summary_and_exit
