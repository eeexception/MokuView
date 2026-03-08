#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Change to the root directory of the project
cd "$(dirname "$0")/.."

echo "Updating Xcode project using xcodegen..."
xcodegen

echo "Project updated successfully!"
