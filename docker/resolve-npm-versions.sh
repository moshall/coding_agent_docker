#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <pinned-file> <resolved-file>" >&2
  exit 1
fi

pinned_file="$1"
resolved_file="$2"
mode="${TOOL_VERSION_CHANNEL:-baseline}"

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s}"
}

lookup_override() {
  local pkg="$1"
  case "${pkg}" in
    "@anthropic-ai/claude-code")
      printf '%s' "${CLAUDE_CODE_VERSION:-}"
      ;;
    "@openai/codex")
      printf '%s' "${CODEX_VERSION:-}"
      ;;
    "@siteboon/claude-code-ui")
      printf '%s' "${CLOUDCLI_VERSION:-}"
      ;;
    "ccman")
      printf '%s' "${CCMAN_VERSION:-}"
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

resolve_latest_version() {
  local pkg="$1"
  npm view "${pkg}" version 2>/dev/null | tr -d '[:space:]'
}

if [[ ! -f "${pinned_file}" ]]; then
  echo "pinned file not found: ${pinned_file}" >&2
  exit 1
fi

>"${resolved_file}"

while IFS= read -r raw_line || [[ -n "${raw_line}" ]]; do
  line="$(trim "${raw_line}")"
  [[ -z "${line}" ]] && continue
  [[ "${line:0:1}" == "#" ]] && continue

  pkg="${line%@*}"
  baseline_version="${line##*@}"
  if [[ "${pkg}" == "${line}" || -z "${baseline_version}" ]]; then
    echo "invalid pinned entry: ${line}" >&2
    exit 1
  fi

  chosen_version="$(lookup_override "${pkg}")"

  if [[ -z "${chosen_version}" && "${mode}" == "latest" ]]; then
    chosen_version="$(resolve_latest_version "${pkg}" || true)"
  fi

  if [[ -z "${chosen_version}" ]]; then
    chosen_version="${baseline_version}"
  fi

  printf '%s@%s\n' "${pkg}" "${chosen_version}" >>"${resolved_file}"
done <"${pinned_file}"

