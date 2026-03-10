#!/bin/bash
set -e

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
XCODEBUILD="$DEVELOPER_DIR/usr/bin/xcodebuild"

PROJECT="ReplaceMe.xcodeproj"
SCHEME="ReplaceMe"
APP_NAME="ReplaceMe"
BUILD_DIR="build"

echo "=== Building $APP_NAME (Release, imzasiz) ==="
"$XCODEBUILD" \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH=$(find "$BUILD_DIR" -name "$APP_NAME.app" -maxdepth 5 | head -1)
if [ -z "$APP_PATH" ]; then
  echo "ERROR: $APP_NAME.app bulunamadi."
  exit 1
fi

echo "=== Extended attributelar temizleniyor ==="
xattr -cr "$APP_PATH"

echo "=== App imzalaniyor ==="
if [ -z "$CODESIGN_IDENTITY" ]; then
  echo "ERROR: CODESIGN_IDENTITY ortam degiskeni tanimli degil."
  echo "Ornek: export CODESIGN_IDENTITY=\"Apple Development: email@example.com (TEAM_ID)\""
  exit 1
fi
codesign --force --deep --sign "$CODESIGN_IDENTITY" \
  --entitlements ReplaceMe.entitlements \
  --options runtime \
  "$APP_PATH"

echo "=== App bulundu: $APP_PATH ==="

DMG_NAME="$APP_NAME.dmg"
DMG_TEMP="$BUILD_DIR/dmg_temp"
DMG_RW="$BUILD_DIR/${APP_NAME}_rw.dmg"

echo "=== DMG icerigi hazirlaniyor ==="
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"
cp -R "$APP_PATH" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

echo "=== Yazilabilir DMG olusturuluyor ==="
rm -f "$DMG_RW"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_TEMP" \
  -ov \
  -format UDRW \
  "$DMG_RW"

echo "=== DMG pencere ayarlari yapiliyor ==="
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_RW" | grep "/Volumes/" | sed 's/.*\/Volumes/\/Volumes/')

# Finder'in pencere ayarlarini uygula
osascript <<EOF
tell application "Finder"
  tell disk "$APP_NAME"
    open
    delay 2
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 200, 660, 440}
    set theViewOptions to icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 80
    delay 1
    set position of item "$APP_NAME.app" of container window to {100, 120}
    delay 1
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

sync
hdiutil detach "$MOUNT_DIR" -quiet

echo "=== Sıkistırılmıs DMG olusturuluyor: $DMG_NAME ==="
rm -f "$DMG_NAME"
hdiutil convert "$DMG_RW" -format UDZO -o "$DMG_NAME"

rm -f "$DMG_RW"
rm -rf "$DMG_TEMP"

xattr -cr "$DMG_NAME"

echo "=== Tamamlandi: $DMG_NAME ==="
