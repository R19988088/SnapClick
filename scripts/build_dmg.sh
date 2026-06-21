#!/bin/bash
set -euo pipefail

# Build a styled DMG for SnapClick.
# Usage: scripts/build_dmg.sh [path/to/SnapClick.app]
# If no app path given, the script builds the Release app via xcodebuild.

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$PROJECT_DIR/scripts"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"

APP_NAME="SnapClick"
VOL_NAME="SnapClick"
DMG_NAME="SnapClick.dmg"

BG_PNG="$SCRIPTS_DIR/dmg_background.png"
BG_PNG_2X="$SCRIPTS_DIR/dmg_background@2x.png"

WIN_W=660
# Background image height. Window content is made a few px taller than this
# so the whole background fits with bottom margin and no scrollbar appears.
WIN_H=440
TITLEBAR_H=28
WIN_CONTENT_H=$((WIN_H + 12))
ICON_SIZE=128
# icon center coordinates within the window content
APP_ICON_X=165
APP_ICON_Y=285
LINK_ICON_X=495
LINK_ICON_Y=285

APP_PATH="${1:-}"

mkdir -p "$BUILD_DIR" "$DIST_DIR"

# 1. Make sure background images exist (regenerate to stay in sync)
echo "==> Generating background image"
python3 "$SCRIPTS_DIR/make_dmg_background.py" "$SCRIPTS_DIR"

# 2. Build app if not provided
if [ -z "$APP_PATH" ]; then
  echo "==> Building $APP_NAME (Release)"
  DERIVED="$BUILD_DIR/DerivedData"
  xcodebuild -project "$PROJECT_DIR/SnapClick.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    build
  APP_PATH="$DERIVED/Build/Products/Release/$APP_NAME.app"
fi

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: app not found at $APP_PATH" >&2
  exit 1
fi
echo "==> Using app: $APP_PATH"

# 3. Prepare staging directory
STAGING="$BUILD_DIR/dmg_staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

# background folder (hidden)
mkdir -p "$STAGING/.background"
cp "$BG_PNG" "$STAGING/.background/background.png"
if [ -f "$BG_PNG_2X" ]; then
  cp "$BG_PNG_2X" "$STAGING/.background/background@2x.png"
  # combine into a tiff so Retina background works
  if command -v tiffutil >/dev/null 2>&1; then
    tiffutil -cathidpicheck "$BG_PNG" "$BG_PNG_2X" \
      -out "$STAGING/.background/background.tiff" >/dev/null 2>&1 || true
  fi
fi

# 4. Create a writable DMG
TMP_DMG="$BUILD_DIR/${APP_NAME}_tmp.dmg"
rm -f "$TMP_DMG"
hdiutil create -srcfolder "$STAGING" -volname "$VOL_NAME" \
  -fs HFS+ -format UDRW -ov "$TMP_DMG"

# 5. Mount it
MOUNT_DIR="/Volumes/$VOL_NAME"
hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TMP_DMG" | \
  egrep '^/dev/' | sed 1q | awk '{print $1}')
sleep 2

# choose background file (tiff if available)
BG_FILE="background.png"
if [ -f "$MOUNT_DIR/.background/background.tiff" ]; then
  BG_FILE="background.tiff"
fi

# 6. Style with AppleScript via Finder
echo "==> Styling DMG window"
osascript <<EOF
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the sidebar width of container window to 0
    set the bounds of container window to {200, 120, 200 + $WIN_W, 120 + $WIN_CONTENT_H + $TITLEBAR_H}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to $ICON_SIZE
    set background picture of viewOptions to file ".background:$BG_FILE"
    set position of item "$APP_NAME.app" of container window to {$APP_ICON_X, $APP_ICON_Y}
    set position of item "Applications" of container window to {$LINK_ICON_X, $LINK_ICON_Y}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

sync
sleep 2

# 7. Detach and convert to compressed read-only DMG
hdiutil detach "$DEVICE" >/dev/null 2>&1 || hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
sleep 1

OUT_DMG="$DIST_DIR/$DMG_NAME"
rm -f "$OUT_DMG"
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUT_DMG"
rm -f "$TMP_DMG"

echo "==> Done: $OUT_DMG"
