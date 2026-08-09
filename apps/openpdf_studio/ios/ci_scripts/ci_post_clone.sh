#!/bin/sh
# Xcode Cloud post-clone script — runs before xcodebuild.
# Flutter's pub get generates ios/Flutter/ephemeral/ (including
# FlutterGeneratedPluginSwiftPackage) which xcodebuild requires to
# resolve Swift Package dependencies.  Without this step the Archive
# action fails immediately with "package cannot be accessed".
set -e

echo "=== ci_post_clone: installing Flutter ==="

# Homebrew is present on Xcode Cloud macOS images.
# Skip re-install if a previous cache layer already has it.
if ! command -v flutter >/dev/null 2>&1; then
  brew install --quiet flutter
fi

FLUTTER="$(command -v flutter)"
echo "Flutter: $FLUTTER  ($(flutter --version --machine 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("frameworkVersion","?"))' 2>/dev/null || echo 'version unknown'))"

echo "=== ci_post_clone: flutter pub get ==="
# CI_WORKSPACE is the repository root set by Xcode Cloud.
cd "$CI_WORKSPACE/apps/openpdf_studio"
flutter pub get

echo "=== ci_post_clone: done ==="
