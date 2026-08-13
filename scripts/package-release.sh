#!/usr/bin/env bash
set -euo pipefail
set -o noclobber

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 RELEASE_TAG [OUTPUT_DIR]" >&2
  exit 2
fi

tag=$1
output_dir=${2:-dist}
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_root/scripts/release-version.sh"
if ! release_version_parse "$tag"; then
  echo "package-release.sh: tag must match vMAJOR.MINOR.PATCH with an optional alpha, beta, or rc suffix: $tag" >&2
  exit 1
fi

output_dir=$(mkdir -p "$output_dir" && cd "$output_dir" && pwd)
archive="HyperWindow-${tag}-macos-universal.dmg"
for output in "$output_dir/$archive" "$output_dir/$archive.sha256"; do
  if [[ -e "$output" ]]; then
    echo "package-release.sh: refusing to overwrite existing output: $output" >&2
    exit 1
  fi
done

"$repo_root/scripts/build-release.sh" "$tag"
app_path="$repo_root/build/Build/Products/Release/HyperWindow.app"
staging=$(mktemp -d "${TMPDIR:-/tmp}/hyperwindow-release.XXXXXX")
cleanup() {
  if [[ -x /usr/bin/trash && -e "$staging" ]]; then
    /usr/bin/trash "$staging" || true
  fi
}
trap cleanup EXIT

ditto "$app_path" "$staging/HyperWindow.app"
ln -s /Applications "$staging/Applications"
hdiutil create \
  -volname "HyperWindow $tag" \
  -srcfolder "$staging" \
  -ov \
  -format UDZO \
  "$output_dir/$archive"
(
  cd "$output_dir"
  shasum -a 256 "$archive" > "$archive.sha256"
)

echo "Created $output_dir/$archive"
echo "Created $output_dir/$archive.sha256"
