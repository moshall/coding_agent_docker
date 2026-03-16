#!/usr/bin/env bash

set -euo pipefail

fail() {
  local message=${1:-"assertion failed"}
  echo "FAIL: ${message}" >&2
  exit 1
}

pass() {
  local message=${1:-"ok"}
  echo "PASS: ${message}"
}

assert_file_exists() {
  local path=$1
  local message=${2:-"file should exist: ${path}"}
  [[ -f "${path}" ]] || fail "${message}"
  pass "${message}"
}

assert_dir_exists() {
  local path=$1
  local message=${2:-"directory should exist: ${path}"}
  [[ -d "${path}" ]] || fail "${message}"
  pass "${message}"
}

assert_contains() {
  local file=$1
  local pattern=$2
  local message=${3:-"${file} should contain ${pattern}"}
  grep -Fq -- "${pattern}" "${file}" || fail "${message}"
  pass "${message}"
}
