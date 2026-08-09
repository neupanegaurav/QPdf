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
# CI_WORKSPACE is the repository root set by Xcode Cloud.
cd "$CI_WORKSPACE/apps/openpdf_studio"
flutter pub get

echo "--- ci_post_clone: complete ---"
