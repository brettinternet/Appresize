#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 RELEASE_TAG MARKETING_VERSION [BUILT_INFO_PLIST]" >&2
  exit 2
fi

source "$(dirname "${BASH_SOURCE[0]}")/release-version.sh"
if ! release_version_parse "$1"; then
  echo "requested release must be a tag such as v1.2.3 or v1.2.3-beta.1: $1" >&2
  exit 1
fi

marketing_version=$2
if [[ "$RELEASE_MARKETING_VERSION" != "$marketing_version" ]]; then
  echo "release version mismatch: tag '$1' does not match MARKETING_VERSION '$marketing_version'" >&2
  exit 1
fi

if [[ $# -eq 3 ]]; then
  plist=$3
  if [[ ! -f "$plist" ]]; then
    echo "built Info.plist not found: $plist" >&2
    exit 1
  fi
  built_version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$plist") || {
    echo "could not read CFBundleShortVersionString from $plist" >&2
    exit 1
  }
  if [[ "$RELEASE_MARKETING_VERSION" != "$built_version" ]]; then
    echo "built app version mismatch: tag '$1' does not match CFBundleShortVersionString '$built_version'" >&2
    exit 1
  fi
fi

echo "release version validated: $RELEASE_FULL_VERSION"
