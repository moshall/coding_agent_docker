#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-PERSIST-01 compose mounts claude config" grep -Fq "config/claude:/home/node/.claude" docker-compose.yml
run_check "TC-PERSIST-02 compose mounts codex config" grep -Fq "config/codex:/home/node/.codex" docker-compose.yml
run_check "TC-PERSIST-03 compose mounts projects" grep -Fq "/projects:/home/node/projects" docker-compose.yml
run_check "TC-PERSIST-04 entrypoint creates dirs" grep -Fq "/home/node/projects" entrypoint.sh
run_check "TC-PERSIST-05 taskmaster global env is generated" grep -Fq "TASKMASTER_ENV" entrypoint.sh

summary_and_exit
