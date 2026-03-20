#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-CCMAN-01 wrapper script exists" test -f ccman-wrapper.sh
run_check "TC-CCMAN-02 wrapper forces root invocations through node" grep -Fq 'exec gosu node env' ccman-wrapper.sh
run_check "TC-CCMAN-03 wrapper forces production mode" grep -Fq 'NODE_ENV=production' ccman-wrapper.sh
run_check "TC-CCMAN-04 wrapper keeps XDG config in node home" grep -Fq 'XDG_CONFIG_HOME="${NODE_XDG_CONFIG_HOME}"' ccman-wrapper.sh
run_check "TC-CCMAN-05 entrypoint links ccman into DATA_ROOT" grep -Fq 'ensure_ln_home "/home/node/.ccman"' entrypoint.sh
run_check "TC-CCMAN-06 entrypoint omits openclaw paths" bash -c '! grep -q openclaw entrypoint.sh'
run_check "TC-CCMAN-07 entrypoint creates ccman home target" grep -Fq "/home/node/.ccman \\" entrypoint.sh

summary_and_exit
