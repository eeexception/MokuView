#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Change directory to the root of the project
cd "$(dirname "$0")/.."

echo "Generating Xcode project using xcodegen..."
xcodegen generate

echo "Building Moku View..."
# We specify CONFIGURATION_BUILD_DIR to ensure the built app goes into a known location
xcodebuild -project MokuView.xcodeproj \
           -scheme MokuView \
           -configuration Release \
           CONFIGURATION_BUILD_DIR="$(pwd)/build/Release" \
           clean build

echo "Build complete! App is located at build/Release/MokuView.app"
