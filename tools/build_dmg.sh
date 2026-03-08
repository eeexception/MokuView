#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Change directory to the root of the project
cd "$(dirname "$0")/.."

APP_NAME="Moku View"
APP_PATH="build/Release/MokuView.app"
DMG_NAME="MokuView.dmg"
DMG_DIR="build/dmg"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found."
    echo "Please run tools/build.sh first before generating DMG."
    exit 1
fi

echo "Creating DMG generation directory..."
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

echo "Copying app to DMG directory..."
cp -r "$APP_PATH" "$DMG_DIR/"

echo "Creating Applications symlink..."
ln -s /Applications "$DMG_DIR/Applications"

echo "Generating DMG..."
rm -f "build/$DMG_NAME"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_DIR" -ov -format UDZO "build/$DMG_NAME"

echo "Cleaning up..."
rm -rf "$DMG_DIR"

echo "DMG generated successfully at build/$DMG_NAME"
