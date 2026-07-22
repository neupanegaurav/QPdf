#!/usr/bin/env bash
# Fail if any native library inside an APK or AAB would break Google Play's
# 16 KB page-size requirement.
#
# Google Play rejects new apps and updates targeting Android 15 or later when a
# shipped .so has LOAD segments aligned below 16 KB. A 4 KB-page device runs
# such a library fine, so ordinary device testing never sees the problem — it
# only appears at upload, or as a compatibility warning on a 16 KB device.
#
# Usage: tool/verify_16kb_alignment.sh <artifact.apk|artifact.aab> [...]

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "usage: $0 <artifact.apk|artifact.aab> [...]" >&2
  exit 2
fi

readelf_bin=""
for candidate in \
  "${ANDROID_HOME:-$HOME/Library/Android/sdk}"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-readelf \
  "$(command -v llvm-readelf || true)" \
  "$(command -v readelf || true)"; do
  if [[ -x "$candidate" ]]; then
    readelf_bin="$candidate"
    break
  fi
done

if [[ -z "$readelf_bin" ]]; then
  echo "no llvm-readelf or readelf found; install the Android NDK or LLVM" >&2
  exit 2
fi

status=0

for artifact in "$@"; do
  if [[ ! -f "$artifact" ]]; then
    echo "missing artifact: $artifact" >&2
    status=1
    continue
  fi

  echo "== $artifact"
  workdir="$(mktemp -d)"
  trap 'rm -rf "$workdir"' EXIT

  # APKs keep libraries under lib/<abi>/, app bundles under base/lib/<abi>/.
  # BUNDLE-METADATA holds debug symbols that never reach a device.
  unzip -q -o "$artifact" 'lib/*' 'base/lib/*' -d "$workdir" 2>/dev/null || true

  found=0
  while IFS= read -r -d '' lib; do
    found=1
    min_align=$(
      "$readelf_bin" -l "$lib" 2>/dev/null |
        awk '/LOAD/ { print $NF }' |
        sort -u |
        while read -r value; do printf '%d\n' "$value"; done |
        sort -n |
        head -1
    )
    rel="${lib#"$workdir"/}"
    if [[ -z "$min_align" ]]; then
      printf '  %-52s no LOAD segments — skipped\n' "$rel"
    elif (( min_align >= 16384 )); then
      printf '  %-52s %8s  ok\n' "$rel" "$min_align"
    else
      printf '  %-52s %8s  FAILS 16 KB requirement\n' "$rel" "$min_align"
      status=1
    fi
  done < <(find "$workdir" -name '*.so' -print0)

  if [[ $found -eq 0 ]]; then
    echo "  no native libraries found"
  fi

  rm -rf "$workdir"
  trap - EXIT
done

if [[ $status -eq 0 ]]; then
  echo
  echo "All native libraries are 16 KB page-size compatible."
else
  echo
  echo "At least one library is below 16 KB alignment; Google Play will reject it." >&2
fi

exit $status
