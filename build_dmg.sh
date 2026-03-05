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
SIGN_IDENTITY="REDACTED_SIGN_IDENTITY"
codesign --force --deep --sign "$SIGN_IDENTITY" \
  --entitlements ReplaceMe.entitlements \
  --options runtime \
  "$APP_PATH"

echo "=== App bulundu: $APP_PATH ==="

DMG_NAME="$APP_NAME.dmg"
echo "=== DMG olusturuluyor: $DMG_NAME ==="

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$APP_PATH" \
  -ov \
  -format UDZO \
  "$DMG_NAME"

echo "=== Tamamlandi: $DMG_NAME ==="
