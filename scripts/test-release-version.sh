#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/release-version.sh"

assert_parse() {
  local tag=$1 expected_marketing=$2 expected_full=$3 expected_prerelease=$4
  release_version_parse "$tag"
  [[ "$RELEASE_MARKETING_VERSION" == "$expected_marketing" ]]
  [[ "$RELEASE_FULL_VERSION" == "$expected_full" ]]
  [[ "$RELEASE_IS_PRERELEASE" == "$expected_prerelease" ]]
}

assert_parse v0.0.9 0.0.9 0.0.9 0
assert_parse v1.2.3-alpha.0 1.2.3 1.2.3-alpha.0 1
[[ "$RELEASE_PRERELEASE" == alpha.0 ]]
assert_parse v1.2.3-beta.12 1.2.3 1.2.3-beta.12 1
assert_parse v1.2.3-rc.1 1.2.3 1.2.3-rc.1 1

for unsupported_tag in \
  v1 v1.2 1.2.3 v01.2.3 v1.02.3 v1.2.03 v1.2.3-preview.1 \
  v1.2.3-beta.01 v1.2.3+ci.4 vv1.2.3; do
  if release_version_parse "$unsupported_tag"; then
    echo "expected $unsupported_tag to be rejected" >&2
    exit 1
  fi
done

echo "release version checks passed"
