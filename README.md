# swift-openapi-generator-binaries

Binary distribution builds for Apple’s [`swift-openapi-generator`](https://github.com/apple/swift-openapi-generator).

This repository tracks upstream releases starting at `1.12.2`. For each tracked release, GitHub Actions builds:

- `darwin-arm64` tarball
- `linux-x86_64` tarball
- `linux-aarch64` tarball
- Debian packages for Linux `amd64` and `arm64`
- `checksums.txt`

## Install

Download the matching asset from a GitHub release, then install the Debian package locally:

```sh
sudo apt install ./swift-openapi-generator_1.12.2_amd64.deb
```

For macOS and tarball Linux installs, unpack the archive and copy `bin/swift-openapi-generator` to a directory on `PATH`.

## Release Workflow

The workflow runs every six hours and discovers upstream releases from `apple/swift-openapi-generator` that are not already published in this repository. It can also be run manually from the Actions tab.

Manual inputs:

- `version`: build one upstream tag, for example `1.12.2`
- `max_releases`: cap the number of missing releases built during discovery
- `include_prereleases`: include upstream prereleases in discovery

Manual `version` runs can build older upstream tags even though scheduled discovery starts at `1.12.2`.

## Packaging Notes

For each release, the workflow reads `swift-tools-version` from `Package.swift` at that upstream tag. macOS installs that Swift toolchain explicitly; Linux uses the corresponding official multi-arch `swift:<version>-jammy` container on Ubuntu 22.04 runners. A major/minor requirement selects the latest patch in that Swift series. This follows the release's declared minimum toolchain rather than a fixed compiler or the runner default; upstream CI tests multiple Swift versions and does not pin one distribution toolchain. Missing or malformed requirements fail during discovery with an error.

Linux binaries use `--static-swift-stdlib`, then are wrapped in `.deb` packages that install `/usr/bin/swift-openapi-generator`. A future Swift release that drops Jammy or support for the macOS runner will still require a runner/container update.

The upstream project is Apache-2.0 licensed. Release archives and Debian packages include Apple’s upstream `LICENSE.txt` and `CONTRIBUTORS.txt`.
