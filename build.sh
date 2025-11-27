#!/bin/bash
set -e

# Build the project for macOS
xcodebuild -project spica.xcodeproj \
           -scheme spica \
           -destination 'platform=macOS' \
           -configuration Debug \
           -derivedDataPath build \
           clean build

echo "Build finished successfully. Artifacts are in ./build"
