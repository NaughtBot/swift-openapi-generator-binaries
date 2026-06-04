#!/usr/bin/env bash
set -euo pipefail

version="${1:?usage: package-deb.sh <version> <deb-arch> <binary> <source-dir> <output-dir>}"
deb_arch="${2:?usage: package-deb.sh <version> <deb-arch> <binary> <source-dir> <output-dir>}"
binary_path="${3:?usage: package-deb.sh <version> <deb-arch> <binary> <source-dir> <output-dir>}"
source_dir="${4:?usage: package-deb.sh <version> <deb-arch> <binary> <source-dir> <output-dir>}"
output_dir="${5:?usage: package-deb.sh <version> <deb-arch> <binary> <source-dir> <output-dir>}"

if [[ "$deb_arch" != "amd64" && "$deb_arch" != "arm64" ]]; then
  printf 'Unsupported Debian architecture: %s\n' "$deb_arch" >&2
  exit 1
fi

deb_version="${version#v}"
package_root="$(mktemp -d)"
trap 'rm -rf "$package_root"' EXIT
chmod 0755 "$package_root"

install -d \
  "${package_root}/DEBIAN" \
  "${package_root}/usr/bin" \
  "${package_root}/usr/share/doc/swift-openapi-generator"

install -m 0755 "$binary_path" "${package_root}/usr/bin/swift-openapi-generator"
install -m 0644 "${source_dir}/LICENSE.txt" "${package_root}/usr/share/doc/swift-openapi-generator/LICENSE.txt"
install -m 0644 "${source_dir}/CONTRIBUTORS.txt" "${package_root}/usr/share/doc/swift-openapi-generator/CONTRIBUTORS.txt"

cat >"${package_root}/usr/share/doc/swift-openapi-generator/copyright" <<EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: swift-openapi-generator
Source: https://github.com/apple/swift-openapi-generator

Files: *
Copyright: 2023 Apple Inc. and the SwiftOpenAPIGenerator project authors
License: Apache-2.0
 See /usr/share/doc/swift-openapi-generator/LICENSE.txt for the full license text.
EOF

installed_size="$(du -sk "${package_root}/usr" | awk '{ print $1 }')"
cat >"${package_root}/DEBIAN/control" <<EOF
Package: swift-openapi-generator
Version: ${deb_version}
Section: devel
Priority: optional
Architecture: ${deb_arch}
Maintainer: NaughtBot <opensource@naughtbot.com>
Installed-Size: ${installed_size}
Depends: libc6 (>= 2.35), libgcc-s1, libstdc++6
Homepage: https://github.com/apple/swift-openapi-generator
Description: Swift OpenAPI Generator command line tool
 Swift OpenAPI Generator creates Swift client and server code from OpenAPI
 documents. This package contains the swift-openapi-generator executable.
EOF

dpkg-deb --build --root-owner-group "$package_root" \
  "${output_dir}/swift-openapi-generator_${deb_version}_${deb_arch}.deb"
