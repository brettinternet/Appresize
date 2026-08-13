#!/usr/bin/env bash

# Parse conventional HyperWindow release tags and expose their version fields.
release_version_parse() {
  local tag=${1-}

  if [[ ! "$tag" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-(alpha|beta|rc)\.(0|[1-9][0-9]*))?$ ]]; then
    return 1
  fi

  RELEASE_MARKETING_VERSION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  RELEASE_FULL_VERSION=${tag#v}
  RELEASE_PRERELEASE=${BASH_REMATCH[5]-}
  if [[ -n "$RELEASE_PRERELEASE" ]]; then
    RELEASE_PRERELEASE+=".${BASH_REMATCH[6]}"
    RELEASE_IS_PRERELEASE=1
  else
    RELEASE_IS_PRERELEASE=0
  fi
}
