#!/usr/bin/env bash
set -euo pipefail

upstream_repository="${UPSTREAM_REPOSITORY:-apple/swift-openapi-generator}"
repository="${GITHUB_REPOSITORY:-}"
version="${VERSION:-}"
max_releases="${MAX_RELEASES:-10}"
include_prereleases="${INCLUDE_PRERELEASES:-false}"
min_upstream_version="${MIN_UPSTREAM_VERSION:-}"

write_output() {
  local name="$1"
  local value="$2"

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf '%s=%s\n' "$name" "$value" >>"$GITHUB_OUTPUT"
  else
    printf '%s=%s\n' "$name" "$value"
  fi
}

json_array_from_lines() {
  jq -Rsc 'split("\n") | map(select(length > 0))'
}

semver_key_filter='
  def semver_key:
    (. | sub("^v"; "") | split(".") | map(tonumber? // 0));
'

if [[ -n "$version" ]]; then
  gh api "repos/${upstream_repository}/releases/tags/${version}" >/dev/null
  versions_json="$(printf '%s\n' "$version" | json_array_from_lines)"
  write_output "versions" "$versions_json"
  write_output "has_releases" "true"
  printf 'Using manually requested upstream release %s.\n' "$version"
  exit 0
fi

if [[ -z "$repository" ]]; then
  printf 'GITHUB_REPOSITORY is required when VERSION is not provided.\n' >&2
  exit 1
fi

if [[ ! "$max_releases" =~ ^[0-9]+$ ]]; then
  printf 'MAX_RELEASES must be a non-negative integer, got %s.\n' "$max_releases" >&2
  exit 1
fi

upstream_releases_file="$(mktemp)"
current_releases_file="$(mktemp)"
missing_releases_file="$(mktemp)"
trap 'rm -f "$upstream_releases_file" "$current_releases_file" "$missing_releases_file"' EXIT

gh api "repos/${upstream_repository}/releases?per_page=100" --paginate \
  --jq '.[] | {tag_name, draft, prerelease, published_at}' >"$upstream_releases_file"

if gh api "repos/${repository}/releases?per_page=100" --paginate \
  --jq '.[] | .tag_name' >"$current_releases_file" 2>/dev/null; then
  :
else
  : >"$current_releases_file"
fi

jq -r \
  --slurpfile current <(jq -R . "$current_releases_file" | jq -s .) \
  --arg include_prereleases "$include_prereleases" \
  --arg min_version "$min_upstream_version" \
  --argjson max_releases "$max_releases" \
  "${semver_key_filter}
  select(.draft == false)
  | select((\$include_prereleases == \"true\") or (.prerelease == false))
  | select(.tag_name | test(\"^v?[0-9]+\\\\.[0-9]+\\\\.[0-9]+([.-].*)?$\")) 
  | select((\$min_version == \"\") or ((.tag_name | semver_key) >= (\$min_version | semver_key)))
  | select((.tag_name as \$tag | \$current[0] | index(\$tag)) | not)
  | [.published_at, .tag_name]
  | @tsv" "$upstream_releases_file" \
  | sort \
  | awk -F '\t' '{ print $2 }' >"$missing_releases_file"

if [[ "$max_releases" != "0" ]]; then
  limited_releases_file="$(mktemp)"
  trap 'rm -f "$upstream_releases_file" "$current_releases_file" "$missing_releases_file" "$limited_releases_file"' EXIT
  awk -v limit="$max_releases" 'NR <= limit { print }' "$missing_releases_file" >"$limited_releases_file"
  mv "$limited_releases_file" "$missing_releases_file"
fi

versions_json="$(json_array_from_lines <"$missing_releases_file")"
release_count="$(jq 'length' <<<"$versions_json")"

write_output "versions" "$versions_json"
if [[ "$release_count" -gt 0 ]]; then
  write_output "has_releases" "true"
  printf 'Discovered %s missing upstream release(s): %s\n' "$release_count" "$versions_json"
else
  write_output "has_releases" "false"
  printf 'No missing upstream releases found.\n'
fi
