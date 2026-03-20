#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-BUILD-01 Dockerfile exists" test -f Dockerfile
run_check "TC-BUILD-02 has Go builder stage" grep -Fq "FROM golang:1.25-bookworm AS go-builder" Dockerfile
run_check "TC-BUILD-03 has Node runtime stage" grep -Fq "FROM node:22-bookworm" Dockerfile
run_check "TC-BUILD-04 has cc-connect artifact copy" grep -Fq "COPY --from=go-builder /build/cc-connect /usr/local/bin/cc-connect" Dockerfile
run_check "TC-BUILD-05 uses official cc-connect repository" grep -Fq "ARG CC_CONNECT_REPO=https://github.com/chenhg5/cc-connect.git" Dockerfile
run_check "TC-BUILD-05b optional cc-connect git ref" grep -Fq "ARG CC_CONNECT_GIT_REF" Dockerfile
run_check "TC-BUILD-15 image records bill of materials" grep -Fq "record-bom.sh" Dockerfile
run_check "TC-BUILD-16 pinned python requirements" test -f docker/python-requirements.txt
run_check "TC-BUILD-06 fallback build is module-independent" grep -Fq 'GO111MODULE=off GOTOOLCHAIN=local go build' Dockerfile
run_check "TC-BUILD-07 runtime image excludes Go apt package" bash -c "! grep -Fq '      golang \\' Dockerfile"
run_check "TC-BUILD-08 runtime image excludes build-essential apt package" bash -c "! grep -Fq '      build-essential \\' Dockerfile"
run_check "TC-BUILD-09 entrypoint supports optional runtime packages" grep -Fq 'installing optional runtime packages' entrypoint.sh
run_check "TC-BUILD-10 entrypoint no longer bootstraps Rust toolchain" bash -c "! grep -Fq 'initializing rust toolchain for mounted cargo directory' entrypoint.sh"
run_check "TC-BUILD-11 runtime image no longer exposes cargo bin path" bash -c "! grep -Fq '/home/node/.cargo/bin' Dockerfile"
run_check "TC-BUILD-12 build no longer clones superpowers repo" bash -c "! grep -Fq 'https://github.com/obra/superpowers' Dockerfile"
run_check "TC-BUILD-13 build no longer clones openclaw skills repo" bash -c "! grep -Fq 'https://github.com/openclaw/skills' Dockerfile"
run_check "TC-BUILD-14 entrypoint syncs only superpowers at runtime" grep -Fq 'sync_repo_as_node "https://github.com/obra/superpowers"' entrypoint.sh

summary_and_exit
