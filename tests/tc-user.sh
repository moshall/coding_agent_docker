#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-USER-01 entrypoint exists" test -f entrypoint.sh
run_check "TC-USER-02 switches to node" grep -Fq 'exec gosu node "$@"' entrypoint.sh

summary_and_exit
