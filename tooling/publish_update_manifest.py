#!/usr/bin/env python3
"""Publishes the Android update manifest for a built APK.

The app polls ``/api/public/app-update``, which reads
``public/downloads/ciss-workforce-android.json`` from the CISS web repo. This
script derives that document from the artifact itself so the advertised hash,
size and version cannot drift from the shipped APK.

Usage:
    tooling/publish_update_manifest.py \
        --apk build/app/outputs/flutter-apk/app-release.apk \
        --downloads /path/to/CISS/public/downloads

The APK is copied to ``<downloads>/ciss-workforce-<version>.apk`` and the JSON
is rewritten in place. Existing ``minimumSupportedVersionCode``,
``mandatory`` and ``releaseNotes`` are preserved unless overridden.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
from datetime import date
from pathlib import Path

PACKAGE_NAME = "co.in.ciss.ciss_mobile"


def read_version(pubspec: Path) -> tuple[str, int]:
    text = pubspec.read_text(encoding="utf-8")
    match = re.search(r"^version:\s*([0-9.]+)\+([0-9]+)", text, re.MULTILINE)
    if not match:
        raise SystemExit("Could not read version from pubspec.yaml")
    return match.group(1), int(match.group(2))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", required=True, type=Path)
    parser.add_argument("--downloads", required=True, type=Path)
    parser.add_argument("--notes", nargs="*", default=None)
    parser.add_argument("--mandatory", choices=["true", "false"], default=None)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    version_name, version_code = read_version(repo_root / "pubspec.yaml")

    apk = args.apk.resolve()
    if not apk.is_file():
        raise SystemExit(f"APK not found: {apk}")

    downloads: Path = args.downloads.resolve()
    manifest_path = downloads / "ciss-workforce-android.json"
    existing: dict = {}
    if manifest_path.is_file():
        existing = json.loads(manifest_path.read_text(encoding="utf-8"))

    target_name = f"ciss-workforce-{version_name}.apk"
    target = downloads / target_name

    manifest = {
        "platform": "android",
        "packageName": PACKAGE_NAME,
        "latestVersionName": version_name,
        "latestVersionCode": version_code,
        "minimumSupportedVersionCode": existing.get(
            "minimumSupportedVersionCode", version_code
        ),
        "apkPath": f"/downloads/{target_name}",
        "sha256": sha256(apk),
        "sizeBytes": apk.stat().st_size,
        "releaseDate": date.today().isoformat(),
        "releaseNotes": args.notes
        if args.notes is not None
        else existing.get("releaseNotes", []),
        "mandatory": (
            args.mandatory == "true"
            if args.mandatory is not None
            else existing.get("mandatory", False)
        ),
    }

    if version_code < manifest["minimumSupportedVersionCode"]:
        raise SystemExit(
            "latestVersionCode is below minimumSupportedVersionCode; "
            "bump the version before publishing."
        )

    if args.dry_run:
        print(json.dumps(manifest, indent=2))
        return 0

    downloads.mkdir(parents=True, exist_ok=True)
    shutil.copy2(apk, target)
    manifest_path.write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )

    print(f"Copied {apk.name} -> {target}")
    print(f"Updated {manifest_path}")
    print(
        f"versionCode={version_code} sha256={manifest['sha256']} "
        f"size={manifest['sizeBytes']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
