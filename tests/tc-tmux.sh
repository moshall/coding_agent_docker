#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-TMUX-01 Dockerfile installs tmux" grep -Fq " tmux " Dockerfile
run_check "TC-TMUX-02 README documents tmux" grep -Fq "tmux" README.md

summary_and_exit
