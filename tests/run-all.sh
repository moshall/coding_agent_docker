#!/usr/bin/env bash

set -euo pipefail

scripts=(
  tests/tc-smoke.sh
  tests/tc-build.sh
  tests/tc-user.sh
  tests/tc-tool.sh
  tests/tc-ccman.sh
  tests/tc-gemini.sh
  tests/tc-versioning.sh
  tests/tc-persist.sh
  tests/tc-mount.sh
  tests/tc-userinit.sh
  tests/tc-env.sh
  tests/tc-workflow.sh
  tests/tc-cron.sh
  tests/tc-tmux.sh
  tests/tc-tailscale.sh
  tests/tc-skills.sh
  tests/tc-port.sh
  tests/tc-release.sh
)

for script in "${scripts[@]}"; do
  echo "== Running ${script} =="
  bash "${script}"
done

echo "All regression scripts completed"
