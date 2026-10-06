#!/usr/bin/env python3
"""Resolve each release's Swift requirement from its own upstream manifest."""

import base64
import json
import os
import re
import subprocess
import sys


def swift_version(manifest):
    match = re.match(
        r"\A\s*//\s*swift-tools-version:\s*(\d+\.\d+(?:\.\d+)?)\s*(?:\n|$)",
        manifest,
    )
    if not match:
        raise ValueError("Package.swift has no valid swift-tools-version directive")
    version = match.group(1)
    # Swift names zero-patch releases 6.2 rather than 6.2.0 in Docker tags.
    return re.sub(r"\.0$", "", version) if version.count(".") == 2 else version


def main():
    repository = os.environ.get("UPSTREAM_REPOSITORY", "apple/swift-openapi-generator")
    releases = []
    for version in json.loads(sys.argv[1]):
        response = subprocess.check_output(
            ["gh", "api", f"repos/{repository}/contents/Package.swift", "-X", "GET", "-f", f"ref={version}"],
            text=True,
        )
        manifest = base64.b64decode(json.loads(response)["content"]).decode()
        swift = swift_version(manifest)
        releases.append({"version": version, "swift_version": swift, "swift_image": f"docker.io/library/swift:{swift}-jammy"})
        print(f"Upstream {version}: Swift {swift} (Package.swift)", file=sys.stderr)
    output = "releases=" + json.dumps(releases, separators=(",", ":")) + "\n"
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as destination:
            destination.write(output)
    else:
        print(output, end="")


if __name__ == "__main__":
    main()
