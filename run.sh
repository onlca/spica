#!/bin/bash
set -e

# Path to the built app
APP_PATH="./build/Build/Products/Debug/spica.app"

if [ -d "$APP_PATH" ]; then
    echo "Launching $APP_PATH..."
    open "$APP_PATH"
else
    echo "Error: App not found at $APP_PATH"
    echo "Please run ./build.sh first."
    exit 1
fi
