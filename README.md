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

Linux binaries are built in the official multi-arch Swift `6.1.3-jammy` container on Ubuntu 22.04 runners with `--static-swift-stdlib`, then wrapped in `.deb` packages that install `/usr/bin/swift-openapi-generator`.

The upstream project is Apache-2.0 licensed. Release archives and Debian packages include Apple’s upstream `LICENSE.txt` and `CONTRIBUTORS.txt`.
