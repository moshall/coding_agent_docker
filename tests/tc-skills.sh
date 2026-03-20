#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-SKILLS-01 installs planning-with-files" grep -Fq "planning-with-files" entrypoint.sh
run_check "TC-SKILLS-02 installs codex skill" grep -Fq "oil-oil/codex" entrypoint.sh
run_check "TC-SKILLS-03 installs ui-ux-pro-max" grep -Fq "ui-ux-pro-max" entrypoint.sh
run_check "TC-SKILLS-04 syncs superpowers repo at startup" grep -Fq 'sync_repo_as_node "https://github.com/obra/superpowers"' entrypoint.sh
run_check "TC-SKILLS-04b superpowers Codex layout per INSTALL.md" grep -Fq 'install_superpowers_for_codex' entrypoint.sh
run_check "TC-SKILLS-04c superpowers Claude plugin install" grep -Fq 'install_superpowers_for_claude' entrypoint.sh
run_check "TC-SKILLS-05 entrypoint omits openclaw/skills clone" bash -c '! grep -Fq "https://github.com/openclaw/skills" entrypoint.sh'
run_check "TC-SKILLS-06 entrypoint persists superpowers under DATA_ROOT" grep -Fq '"${DATA_ROOT}/config/superpowers"' entrypoint.sh
run_check "TC-SKILLS-07 entrypoint persists ~/.agents under DATA_ROOT" grep -Fq '"${DATA_ROOT}/config/agents"' entrypoint.sh
run_check "TC-SKILLS-08 compose omits openclaw-skills volume" bash -c '! grep -Fq "config/openclaw-skills:" docker-compose.yml'

summary_and_exit
