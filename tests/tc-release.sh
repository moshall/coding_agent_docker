#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-RELEASE-01 Docker Hub description exists" test -f DOCKER_HUB_DESCRIPTION.md
run_check "TC-RELEASE-02 release notes exist" test -f RELEASE_NOTES.md
run_check "TC-RELEASE-03 upgrading guide exists" test -f UPGRADING.md

summary_and_exit
