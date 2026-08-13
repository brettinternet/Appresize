#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "usage: $0 [RELEASE_TAG]" >&2
  exit 2
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
build_dir="$repo_root/build"
app_path="$build_dir/Build/Products/Release/HyperWindow.app"

xcodebuild \
  -project "$repo_root/HyperWindow.xcodeproj" \
  -scheme HyperWindow \
  -configuration Release \
  -derivedDataPath "$build_dir" \
  -destination 'generic/platform=macOS' \
  build

/usr/bin/xcrun swift "$repo_root/scripts/sign-local-app.swift" "$app_path"

binary_path="$app_path/Contents/MacOS/HyperWindow"
archs=$(lipo -archs "$binary_path")
if [[ "$archs" != *arm64* || "$archs" != *x86_64* ]]; then
  echo "build-release.sh: expected a universal arm64/x86_64 binary, found: $archs" >&2
  exit 1
fi
codesign --verify --deep --strict "$app_path"
signature=$(codesign -d --verbose=4 "$app_path" 2>&1)
if [[ "$signature" != *flags=*runtime* ]]; then
  echo "build-release.sh: hardened runtime is not enabled" >&2
  exit 1
fi

if [[ $# -eq 1 ]]; then
  marketing_version=$(
    xcodebuild \
      -project "$repo_root/HyperWindow.xcodeproj" \
      -scheme HyperWindow \
      -configuration Release \
      -showBuildSettings |
      awk -F ' = ' '$1 ~ /^[[:space:]]*MARKETING_VERSION$/ { print $2; exit }'
  )
  "$repo_root/scripts/validate-release-version.sh" \
    "$1" "$marketing_version" "$app_path/Contents/Info.plist"
fi

echo "Built $app_path"
