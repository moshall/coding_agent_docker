#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-BUILD-01 Dockerfile exists" test -f Dockerfile
run_check "TC-BUILD-02 has Go builder stage" grep -Fq "FROM golang:1.22-bookworm AS go-builder" Dockerfile
run_check "TC-BUILD-03 has Node runtime stage" grep -Fq "FROM node:22-bookworm" Dockerfile
run_check "TC-BUILD-04 has cc-connect artifact copy" grep -Fq "COPY --from=go-builder /build/cc-connect /usr/local/bin/cc-connect" Dockerfile

summary_and_exit
