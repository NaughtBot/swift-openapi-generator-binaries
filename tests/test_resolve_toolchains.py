import base64
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "resolve_toolchains", Path(__file__).parents[1] / "scripts/resolve-toolchains.py"
)
resolver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(resolver)


class ToolchainTests(unittest.TestCase):
    def test_manifest_versions(self):
        for directive, expected in [("6.1", "6.1"), ("6.2.0", "6.2"), ("6.2.3", "6.2.3")]:
            with self.subTest(directive=directive):
                self.assertEqual(resolver.swift_version(f"// swift-tools-version:{directive}\nimport PackageDescription\n"), expected)

    def test_invalid_manifest_fails(self):
        for manifest in ["", "// swift-tools-version:latest\n", "// swift-tools-version:6.2.bad\n", "// swift-tools-version:6.2; invalid\n", "import PackageDescription\n// swift-tools-version:6.2\n"]:
            with self.subTest(manifest=manifest), self.assertRaises(ValueError):
                resolver.swift_version(manifest)

    def test_release_specific_matrix_output(self):
        manifests = ["// swift-tools-version:6.1\n", "// swift-tools-version:6.2\n"]
        responses = [json.dumps({"content": base64.b64encode(m.encode()).decode()}) for m in manifests]
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "output"
            with patch.dict(os.environ, {"GITHUB_OUTPUT": str(output), "UPSTREAM_REPOSITORY": "apple/swift-openapi-generator"}), patch("sys.argv", ["resolver", '["1.12.2","1.14.0"]']), patch.object(resolver.subprocess, "check_output", side_effect=responses) as api, contextlib.redirect_stderr(io.StringIO()):
                resolver.main()
            matrix = json.loads(output.read_text().removeprefix("releases="))
            self.assertEqual([r["swift_version"] for r in matrix], ["6.1", "6.2"])
            self.assertEqual(matrix[1]["swift_image"], "docker.io/library/swift:6.2-jammy")
            self.assertEqual([c.args[0][-1] for c in api.call_args_list], ["ref=1.12.2", "ref=1.14.0"])


if __name__ == "__main__":
    unittest.main()
