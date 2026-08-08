#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mobile_version="$(tr -d '[:space:]' < "$repo_root/VERSION")"

if [[ -z "$mobile_version" ]]; then
  echo "VERSION is empty" >&2
  exit 1
fi

grep -Fq "versionName = \"$mobile_version\"" \
  "$repo_root/android/app/build.gradle.kts" || {
    echo "Android versionName does not match VERSION ($mobile_version)" >&2
    exit 1
  }

ios_matches="$(grep -Fc "MARKETING_VERSION = $mobile_version" \
  "$repo_root/ios/HermesStudio.xcodeproj/project.pbxproj")"
if [[ "$ios_matches" -lt 2 ]]; then
  echo "iOS MARKETING_VERSION does not match VERSION ($mobile_version)" >&2
  exit 1
fi

echo "Hermes Studio Mobile version is aligned at $mobile_version"
