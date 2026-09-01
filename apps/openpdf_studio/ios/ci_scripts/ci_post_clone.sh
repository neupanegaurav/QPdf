#!/bin/sh
# Xcode Cloud post-clone hook — must run before xcodebuild.
#
# Flutter's `pub get` generates ios/Flutter/ephemeral/ including
# FlutterGeneratedPluginSwiftPackage. Without it xcodebuild fails
# immediately on Swift Package resolution.
set -e

echo "--- ci_post_clone: locating Flutter ---"

# Add both Homebrew prefixes to PATH (Apple Silicon vs Intel).
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if command -v flutter >/dev/null 2>&1; then
    echo "Flutter already in PATH: $(flutter --version 2>&1 | head -1)"
elif command -v brew >/dev/null 2>&1; then
    echo "Installing Flutter via Homebrew..."
    brew install flutter
    echo "Flutter installed: $(flutter --version 2>&1 | head -1)"
else
    echo "Homebrew not found — cloning Flutter stable branch..."
    FLUTTER_HOME="$HOME/flutter"
    git clone https://github.com/flutter/flutter.git \
        --depth 1 --branch stable "$FLUTTER_HOME"
    export PATH="$FLUTTER_HOME/bin:$PATH"
    echo "Flutter cloned: $(flutter --version 2>&1 | head -1)"
fi

echo "--- ci_post_clone: precaching iOS artifacts ---"
flutter precache --ios 2>&1 || true

echo "--- ci_post_clone: flutter pub get ---"
# $CI_WORKSPACE is unset in this Xcode Cloud environment (observed empty on
# build 13, 2026-09-01, turning the cd into the bogus absolute path
# "/apps/openpdf_studio"). Derive the Flutter project root from the script's
# own location instead: ios/ci_scripts/ci_post_clone.sh -> ios -> project root.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/../.."
flutter pub get

echo "--- ci_post_clone: complete ---"
