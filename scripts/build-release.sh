#!/usr/bin/env bash
set -euo pipefail

version="${1:?usage: build-release.sh <version> <platform> <deb-arch>}"
platform="${2:?usage: build-release.sh <version> <platform> <deb-arch>}"
deb_arch="${3:-}"

upstream_url="${UPSTREAM_URL:-https://github.com/apple/swift-openapi-generator.git}"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="${root_dir}/dist"
work_dir="${RUNNER_TEMP:-${root_dir}/.work}/swift-openapi-generator-${version}-${platform}"
source_dir="${work_dir}/source"
package_name="swift-openapi-generator-${version}-${platform}"
archive_stage="${work_dir}/${package_name}"

rm -rf "$dist_dir" "$work_dir"
mkdir -p "$dist_dir" "$archive_stage/bin" "$archive_stage/share/doc/swift-openapi-generator"

git clone --depth 1 --branch "$version" "$upstream_url" "$source_dir"

(
  cd "$source_dir"
  swift --version

  build_args=(build --configuration release --product swift-openapi-generator)
  if [[ "$platform" == linux-* ]]; then
    build_args+=(--static-swift-stdlib)
  fi

  swift "${build_args[@]}"
  bin_dir="$(swift build --configuration release --show-bin-path)"
  install -m 0755 "${bin_dir}/swift-openapi-generator" "${archive_stage}/bin/swift-openapi-generator"

  "${archive_stage}/bin/swift-openapi-generator" --help >"${work_dir}/swift-openapi-generator-help.txt"
)

cp "${source_dir}/LICENSE.txt" "${archive_stage}/share/doc/swift-openapi-generator/LICENSE.txt"
cp "${source_dir}/CONTRIBUTORS.txt" "${archive_stage}/share/doc/swift-openapi-generator/CONTRIBUTORS.txt"
cat >"${archive_stage}/README.txt" <<EOF
swift-openapi-generator ${version} ${platform}

This binary was built from:
${upstream_url}

Upstream tag:
${version}

Install by copying bin/swift-openapi-generator to a directory on PATH.
EOF

tar -C "$work_dir" -czf "${dist_dir}/${package_name}.tar.gz" "$package_name"

if [[ "$platform" == linux-* ]]; then
  if [[ -z "$deb_arch" ]]; then
    printf 'A Debian architecture is required for Linux platform %s.\n' "$platform" >&2
    exit 1
  fi

  "${root_dir}/scripts/package-deb.sh" \
    "$version" \
    "$deb_arch" \
    "${archive_stage}/bin/swift-openapi-generator" \
    "$source_dir" \
    "$dist_dir"
fi

printf 'Created release assets:\n'
find "$dist_dir" -maxdepth 1 -type f -print
