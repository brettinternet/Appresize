#!/bin/bash

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 REQUESTED_VERSION MARKETING_VERSION [BUILT_INFO_PLIST]" >&2
  exit 2
fi

normalize_version() {
  local label=$1
  local value=$2

  if [[ -z "$value" ]]; then
    echo "$label must not be empty" >&2
    exit 1
  fi

  # Tags commonly have one leading v while MARKETING_VERSION does not.
  # Remove at most one prefix so malformed values such as vv1.2.3 fail.
  if [[ "$value" == v* ]]; then
    value=${value#v}
  fi
  if [[ -z "$value" ]]; then
    echo "$label must contain a version after its leading v" >&2
    exit 1
  fi
  if [[ "$value" == v* ]]; then
    echo "$label must have at most one leading v" >&2
    exit 1
  fi

  printf '%s' "$value"
}

requested_version=$(normalize_version requested "$1")
marketing_version=$(normalize_version MARKETING_VERSION "$2")

if [[ "$requested_version" != "$marketing_version" ]]; then
  echo "release version mismatch: requested '$1' does not match MARKETING_VERSION '$2'" >&2
  exit 1
fi

if [[ $# -eq 3 ]]; then
  plist=$3
  if [[ ! -f "$plist" ]]; then
    echo "built Info.plist not found: $plist" >&2
    exit 1
  fi
  built_value=$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$plist") || {
    echo "could not read CFBundleShortVersionString from $plist" >&2
    exit 1
  }
  built_version=$(normalize_version CFBundleShortVersionString "$built_value")
  if [[ "$requested_version" != "$built_version" ]]; then
    echo "built app version mismatch: requested '$1' does not match CFBundleShortVersionString '$built_value'" >&2
    exit 1
  fi
fi

echo "release version validated: $requested_version"
