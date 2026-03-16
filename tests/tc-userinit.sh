#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-USERINIT-01 template exists" test -f user-init.sh.example
run_check "TC-USERINIT-02 entrypoint hook exists" grep -Fq "USER_INIT=\"\${DATA_ROOT}/user-init.sh\"" entrypoint.sh
run_check "TC-USERINIT-03 entrypoint runs hook" grep -Fq "running user-init.sh" entrypoint.sh

summary_and_exit
