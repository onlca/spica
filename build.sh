#!/bin/bash
set -e

PROJECT_FILE="spica.xcodeproj/project.pbxproj"
CONFIGURATION="Debug"
NEW_VERSION=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --release) CONFIGURATION="Release" ;;
        --version) NEW_VERSION="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

echo "Configuration: $CONFIGURATION"

# Function to get build setting
get_build_setting() {
    local setting=$1
    grep "$setting =" "$PROJECT_FILE" | head -n 1 | sed -E "s/.*$setting = (.*);/\1/"
}

# Update Marketing Version if provided
if [ -n "$NEW_VERSION" ]; then
    echo "Updating Marketing Version to $NEW_VERSION..."
    sed -i '' "s/MARKETING_VERSION = .*/MARKETING_VERSION = $NEW_VERSION;/g" "$PROJECT_FILE"
fi

# Auto-increment Build Number
CURRENT_BUILD=$(get_build_setting "CURRENT_PROJECT_VERSION")
# Trim whitespace
CURRENT_BUILD=$(echo "$CURRENT_BUILD" | xargs)
NEW_BUILD=$((CURRENT_BUILD + 1))
echo "Incrementing Build Number from $CURRENT_BUILD to $NEW_BUILD..."
sed -i '' "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PROJECT_FILE"

# Build the project
echo "Building project..."
xcodebuild -project spica.xcodeproj \
           -scheme spica \
           -destination 'platform=macOS' \
           -configuration "$CONFIGURATION" \
           -derivedDataPath build \
           clean build

echo "Build finished successfully."
echo "Artifacts are in ./build/Build/Products/$CONFIGURATION"
