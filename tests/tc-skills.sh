#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-SKILLS-01 installs planning-with-files" grep -Fq "planning-with-files" entrypoint.sh
run_check "TC-SKILLS-02 installs data-analyst" grep -Fq "data-analyst" entrypoint.sh
run_check "TC-SKILLS-03 installs codex skill" grep -Fq "oil-oil/codex" entrypoint.sh
run_check "TC-SKILLS-04 installs ui-ux-pro-max" grep -Fq "ui-ux-pro-max" entrypoint.sh

summary_and_exit
