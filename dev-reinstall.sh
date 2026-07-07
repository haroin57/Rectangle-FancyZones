#!/bin/bash
# Dev loop: build, cert-sign (stable self-signed identity), reinstall, relaunch.
# Keeps the same Designated Requirement so the Accessibility grant persists.
set -e
REPO="$(cd "$(dirname "$0")" && pwd)"
KC=/tmp/fzsign.keychain-db
ID="Rectangle FancyZones Local"
APP=/Applications/Rectangle.app
BUILT="$REPO/build/Build/Products/Release/Rectangle.app"

echo "==> build"
rm -rf "$REPO/build"
xcodebuild -project "$REPO/Rectangle.xcodeproj" -scheme Rectangle -configuration Release \
  -derivedDataPath "$REPO/build" CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES -skipPackagePluginValidation build > /tmp/fzbuild.log 2>&1
grep -q "BUILD SUCCEEDED" /tmp/fzbuild.log || { echo "BUILD FAILED"; grep -iE " error:" /tmp/fzbuild.log | grep -v note: | head; exit 1; }
echo "==> build ok"

security unlock-keychain -p fzpass "$KC"
security list-keychains -d user -s "$KC" $(security list-keychains -d user | sed 's/"//g' | xargs) >/dev/null

osascript -e 'quit app "Rectangle"' 2>/dev/null || true
sleep 1
rm -rf "$APP.prev"; [ -d "$APP" ] && mv "$APP" "$APP.prev"
cp -R "$BUILT" "$APP"

echo "==> sign inside-out"
for t in \
  "$APP/Contents/Library/LoginItems/RectangleLauncher.app" \
  "$APP"/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/*.xpc \
  "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" \
  "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app" \
  "$APP/Contents/Frameworks/Sparkle.framework" \
  "$APP" ; do
  codesign --keychain "$KC" --force --timestamp=none --sign "$ID" "$t" >/dev/null 2>&1 || echo "  sign FAIL: $t"
done
codesign -d --requirements - "$APP" 2>&1 | grep -i designated

# restore search list (drop temp keychain)
security list-keychains -d user -s $(security list-keychains -d user | sed 's/"//g' | grep -v fzsign | xargs) >/dev/null
open "$APP"
echo "==> installed + launched"
