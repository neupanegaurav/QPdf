#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
app_root="$repo_root/apps/openpdf_studio"
dist_root="$repo_root/dist"

if [ -d /Applications/Xcode.app/Contents/Developer ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  unset QPDF_ALLOW_MISSING_DSYM || true
elif [ -d /Applications/Xcode-beta.app/Contents/Developer ]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
  export QPDF_ALLOW_MISSING_DSYM=1
else
  echo "QPdf Apple build: full Xcode was not found." >&2
  exit 69
fi

export PATH="$repo_root/tool/xcode-beta-bin:$PATH"
mkdir -p "$dist_root"

cd "$app_root"
flutter pub get
flutter build ios --debug --no-codesign
flutter build ios --profile
flutter build macos --release

# lib_llama_cpp_macos 0.7.3 is distributed with framework links expanded into
# duplicate directories. Xcode can compile that archive, but codesign correctly
# rejects the resulting bundle as ambiguous. Restore the canonical versioned
# framework links inside the disposable build output before applying QPdf's
# local ad-hoc test signature. Never rewrite the package cache itself.
llama_framework="$app_root/build/macos/Build/Products/Release/QPdf.app/Contents/Frameworks/lib_llama_cpp_macos.framework"
if [ -d "$llama_framework/Versions/A" ] &&
  [ -d "$llama_framework/Versions/Current" ] &&
  [ ! -L "$llama_framework/Versions/Current" ]; then
  rm -R "$llama_framework/Versions/Current"
  ln -s A "$llama_framework/Versions/Current"
  rm -R "$llama_framework/Resources"
  rm "$llama_framework/lib_llama_cpp_macos"
  ln -s Versions/Current/Resources "$llama_framework/Resources"
  ln -s Versions/Current/lib_llama_cpp_macos \
    "$llama_framework/lib_llama_cpp_macos"
fi

# Flutter/Xcode can update App.framework after the outer ad-hoc bundle seal is
# written. Re-seal the complete local test bundle so strict verification and
# Gatekeeper inspection see one coherent revision. Public distribution still
# requires Developer ID signing and notarization in the release pipeline.
codesign --force --deep --sign - --timestamp=none \
  "$app_root/build/macos/Build/Products/Release/QPdf.app"
codesign --verify --deep --strict \
  "$app_root/build/macos/Build/Products/Release/QPdf.app"

payload_root=$(mktemp -d "${TMPDIR:-/tmp}/qpdf-payload.XXXXXX")
trap 'rm -rf "$payload_root"' EXIT HUP INT TERM
mkdir -p "$payload_root/Payload"
ditto "$app_root/build/ios/iphoneos/Runner.app" \
  "$payload_root/Payload/Runner.app"
ditto -c -k --sequesterRsrc --keepParent "$payload_root/Payload" \
  "$dist_root/QPdf-0.1.0-ios-profile.ipa"
ditto -c -k --sequesterRsrc --keepParent \
  "$app_root/build/macos/Build/Products/Release/QPdf.app" \
  "$dist_root/QPdf-0.1.0-macos-universal.zip"

# Refresh the other locally built artifacts too, so one packaging run cannot
# leave checksums pointing at a previous feature set.
cp "$app_root/build/app/outputs/flutter-apk/app-debug.apk" \
  "$dist_root/QPdf-0.1.0-android-debug.apk"
cp "$app_root/build/app/outputs/bundle/release/app-release.aab" \
  "$dist_root/QPdf-0.1.0-android-release-unsigned.aab"
ditto -c -k --sequesterRsrc --keepParent "$app_root/build/web" \
  "$dist_root/QPdf-0.1.0-web-wasm.zip"

cd "$dist_root"
shasum -a 256 \
  QPdf-0.1.0-android-debug.apk \
  QPdf-0.1.0-android-release-unsigned.aab \
  QPdf-0.1.0-ios-profile.ipa \
  QPdf-0.1.0-macos-universal.zip \
  QPdf-0.1.0-web-wasm.zip > SHA256SUMS
shasum -a 256 -c SHA256SUMS
shasum -a 256 QPdf-0.1.0-android-debug.apk \
  > QPdf-0.1.0-android-debug.apk.sha256
