#!/usr/bin/env bash
set -euo pipefail

version="${1:?usage: publish-release.sh <version> <asset-dir>}"
asset_dir="${2:-dist}"
upstream_repository="${UPSTREAM_REPOSITORY:-apple/swift-openapi-generator}"
repository="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"

if [[ ! -d "$asset_dir" ]]; then
  printf 'Asset directory does not exist: %s\n' "$asset_dir" >&2
  exit 1
fi

shopt -s nullglob
assets=("$asset_dir"/*)
if [[ "${#assets[@]}" -eq 0 ]]; then
  printf 'No assets found in %s.\n' "$asset_dir" >&2
  exit 1
fi

(
  cd "$asset_dir"
  rm -f checksums.txt
  sha256sum -- * >checksums.txt
)

upstream_url="$(gh api "repos/${upstream_repository}/releases/tags/${version}" --jq '.html_url')"
upstream_body_file="$(mktemp)"
notes_file="$(mktemp)"
trap 'rm -f "$upstream_body_file" "$notes_file"' EXIT

gh api "repos/${upstream_repository}/releases/tags/${version}" --jq '.body // ""' >"$upstream_body_file"

cat >"$notes_file" <<EOF
Binary distribution for apple/swift-openapi-generator ${version}.

Upstream release: ${upstream_url}

Linux users can install the Debian package directly, for example:

\`\`\`sh
sudo apt install ./swift-openapi-generator_${version#v}_amd64.deb
\`\`\`

Checksums are in \`checksums.txt\`.

Upstream release notes follow.

EOF
cat "$upstream_body_file" >>"$notes_file"

assets=("$asset_dir"/*)
if gh release view "$version" --repo "$repository" >/dev/null 2>&1; then
  gh release edit "$version" --repo "$repository" --title "$version" --notes-file "$notes_file"
  gh release upload "$version" --repo "$repository" --clobber "${assets[@]}"
else
  gh release create "$version" --repo "$repository" "${assets[@]}" --title "$version" --notes-file "$notes_file"
fi
