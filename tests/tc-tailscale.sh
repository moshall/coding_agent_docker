#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-TAILSCALE-01 compose has NET_ADMIN" grep -Fq "NET_ADMIN" docker-compose.yml
run_check "TC-TAILSCALE-02 compose has tun device" grep -Fq "/dev/net/tun:/dev/net/tun" docker-compose.yml
run_check "TC-TAILSCALE-03 Dockerfile installs tailscale" grep -Fq "apt-get install -y --no-install-recommends tailscale" Dockerfile

summary_and_exit
