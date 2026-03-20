#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-PERSIST-01 compose mounts only data root" grep -Fq '${DATA_ROOT:-/data/coding-agent}:${DATA_ROOT:-/data/coding-agent}' docker-compose.yml
run_check "TC-PERSIST-02 compose no per-tool bind mounts" bash -c '! grep -Fq "config/claude:/home/node/.claude" docker-compose.yml'
run_check "TC-PERSIST-03 entrypoint links from DATA_ROOT" grep -Fq "link_persistence_from_data_root" entrypoint.sh
run_check "TC-PERSIST-04 compose no longer mounts cargo home" bash -c "! grep -Fq 'config/cargo:/home/node/.cargo' docker-compose.yml"
run_check "TC-PERSIST-05 entrypoint links project workspace" grep -Fq 'ensure_ln_home "/home/node/project"' entrypoint.sh
run_check "TC-PERSIST-06 taskmaster global env is generated" grep -Fq "TASKMASTER_ENV" entrypoint.sh
run_check "TC-PERSIST-07 root DATA_ROOT traversal for node (1Panel)" grep -Fq "ensure_data_root_traversable_for_node" entrypoint.sh

summary_and_exit
