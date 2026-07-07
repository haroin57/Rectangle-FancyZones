#!/bin/bash
# Build Rectangle (with the FancyZones custom-zone feature) and reinstall it
# into /Applications. Requires full Xcode (Command Line Tools alone cannot
# compile the storyboards / asset catalog).
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$REPO/build"
APP="Rectangle.app"

echo "==> Verifying Xcode toolchain"
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "ERROR: xcodebuild not available. Install Xcode and run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi
xcodebuild -version

echo "==> Building Rectangle (Release, unsigned local build)"
xcodebuild \
  -project "$REPO/Rectangle.xcodeproj" \
  -scheme Rectangle \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  build

BUILT="$BUILD_DIR/Build/Products/Release/$APP"
if [ ! -d "$BUILT" ]; then
  echo "ERROR: build did not produce $BUILT"; exit 1
fi
echo "==> Built: $BUILT"

echo "==> Quitting any running Rectangle"
osascript -e 'quit app "Rectangle"' 2>/dev/null || true
sleep 1

echo "==> Installing to /Applications (backing up the old app)"
if [ -d "/Applications/$APP" ]; then
  rm -rf "/Applications/$APP.prev"
  mv "/Applications/$APP" "/Applications/$APP.prev"
fi
cp -R "$BUILT" "/Applications/$APP"

echo "==> Launching"
open "/Applications/$APP"

echo "==> Done. Enable the feature with:"
echo "     defaults write com.knollsoft.Rectangle fancyZonesEnabled -bool true"
echo "   then hold the zone modifier (default: Control) while dragging a window."
