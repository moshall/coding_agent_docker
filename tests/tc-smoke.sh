#!/usr/bin/env bash

set -euo pipefail

source tests/lib/assert.sh

echo "[TC-SMOKE] Core project files"
assert_file_exists Dockerfile "Dockerfile exists"
assert_file_exists entrypoint.sh "entrypoint.sh exists"
assert_file_exists docker-compose.yml "docker-compose.yml exists"
assert_file_exists docker-compose.dev.yml "docker-compose.dev.yml exists"
assert_file_exists .env.example ".env.example exists"
assert_file_exists user-init.sh.example "user-init.sh.example exists"
assert_file_exists README.md "README.md exists"
assert_file_exists .github/workflows/build-push.yml "GitHub workflow exists"

echo "[TC-SMOKE] Key content"
assert_contains Dockerfile "FROM golang:1.25-bookworm AS go-builder" "Dockerfile has Go builder stage"
assert_contains Dockerfile "FROM node:22-bookworm" "Dockerfile has Node runtime stage"
assert_contains entrypoint.sh 'exec gosu node "$@"' "Entrypoint switches to node user"
assert_contains docker-compose.yml "NET_ADMIN" "Compose includes NET_ADMIN capability"
assert_contains docker-compose.yml "MOUNT_OPENCLAW" "Compose includes optional OpenClaw mount"
assert_contains .env.example "TASKMASTER_MAIN_PROVIDER" ".env template includes Task Master config"
