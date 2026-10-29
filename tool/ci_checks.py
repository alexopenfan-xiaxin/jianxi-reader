#!/usr/bin/env python3
"""Release-metadata gate for CI.

Runs without the Flutter SDK: it parses `pubspec.yaml`, the About page fallback
and `AndroidManifest.xml`, so the checks that protect the release contract fail
in seconds instead of after a ten-minute Android build.
"""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ElementTree
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ANDROID_NS = "{http://schemas.android.com/apk/res/android}"

# v2.9.9+199 was the last public build; versionCode must keep growing.
LAST_PUBLISHED_BUILD = 199

failures: list[str] = []


def fail(message: str) -> None:
    failures.append(message)
    print(f"::error::{message}")


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def check_version_sync() -> tuple[str, str]:
    match = re.search(r"^version:\s*(\S+)\s*$", read("pubspec.yaml"), re.MULTILINE)
    if match is None:
        fail("pubspec.yaml has no `version:` line")
        return "", ""
    version = match.group(1)
    name, separator, build = version.partition("+")
    if not separator or not name or not build.isdigit():
        fail(f"pubspec version '{version}' is not '<name>+<numeric build>'")
        return name, build

    fallback = re.search(
        r"_fallbackBuildNumber\s*=\s*'([^']*)'",
        read("lib/features/settings/about_settings.dart"),
    )
    if fallback is None:
        fail("about_settings.dart no longer defines _fallbackBuildNumber")
    elif fallback.group(1) != build:
        fail(
            "version drift: pubspec build "
            f"'{build}' != _fallbackBuildNumber '{fallback.group(1)}'"
        )

    if int(build) <= LAST_PUBLISHED_BUILD:
        fail(
            f"build number {build} must be greater than the last published "
            f"build {LAST_PUBLISHED_BUILD} (updates compare it directly)"
        )

    print(f"ok  version {name} (build {build}) matches the About fallback")
    return name, build


def check_manifest() -> None:
    tree = ElementTree.parse(ROOT / "android/app/src/main/AndroidManifest.xml")
    application = tree.getroot().find("application")
    if application is None:
        fail("AndroidManifest.xml has no <application>")
        return

    allow_backup = application.get(f"{ANDROID_NS}allowBackup")
    if allow_backup != "false":
        fail(
            "allowBackup must be false: imported document mirrors and reading "
            f"records would otherwise be uploaded to the system backup (got {allow_backup!r})"
        )
    else:
        print("ok  allowBackup=false")

    for intent_filter in application.iter("intent-filter"):
        for data in intent_filter.findall("data"):
            mime = data.get(f"{ANDROID_NS}mimeType")
            if mime == "text/plain":
                fail(
                    "a VIEW intent-filter still accepts text/plain, which makes "
                    "简兮 a candidate for every .txt file"
                )

    mimes = {
        data.get(f"{ANDROID_NS}mimeType")
        for data in application.iter("data")
        if data.get(f"{ANDROID_NS}mimeType")
    }
    for expected in ("text/markdown", "text/html"):
        if expected not in mimes:
            fail(f"manifest lost its {expected} intent filter")
    print(f"ok  declaration-only mime filters: {sorted(mimes)}")


def main() -> int:
    check_version_sync()
    check_manifest()
    if failures:
        print(f"\n{len(failures)} release-metadata check(s) failed.")
        return 1
    print("\nAll release-metadata checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
