#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
dist_dir="$repo_dir/dist"

cd "$dist_dir"
shasum -a 256 -c SHA256SUMS

for archive in \
  QPdf-0.1.0-ios-profile.ipa \
  QPdf-0.1.0-macos-universal.zip \
  QPdf-0.1.0-web-wasm.zip
do
  unzip -tq "$archive" >/dev/null
  echo "$archive: archive structure OK"
done

android_sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
if [ -n "$android_sdk" ]; then
  apksigner=$(find "$android_sdk/build-tools" -type f -name apksigner 2>/dev/null | sort -V | tail -n 1)
else
  apksigner=""
fi

if [ -n "$apksigner" ]; then
  "$apksigner" verify --verbose QPdf-0.1.0-android-debug.apk
else
  echo "Android apksigner not found; SHA-256 verification completed."
fi

aab_verification=$(jarsigner -verify QPdf-0.1.0-android-release-unsigned.aab 2>&1 || true)
if echo "$aab_verification" | grep -q "jar is unsigned"; then
  echo "QPdf-0.1.0-android-release-unsigned.aab: unsigned as documented"
else
  echo "Expected an unsigned AAB, but its signing state was unexpected." >&2
  exit 1
fi
