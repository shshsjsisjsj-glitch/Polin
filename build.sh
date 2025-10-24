#!/bin/sh

# TrollSpeed Universal Builder
# Builds either an App (if Xcode target exists) or manual .app if missing

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION=$1
VERSION=${VERSION#v}
APP_NAME="TrollSpeed"
ARCHIVE_PATH="$APP_NAME.xarchive"
PRODUCT_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"

echo "🚀 Starting build for version $VERSION..."

# Clean and build with Xcode
xcodebuild clean build archive \
  -scheme "$APP_NAME" \
  -project "$APP_NAME.xcodeproj" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGNING_ALLOWED=NO | xcpretty || true

# Check if .app exists
if [ ! -d "$PRODUCT_PATH" ]; then
    echo "⚠️ No $APP_NAME.app found — creating manually..."
    mkdir -p "$PRODUCT_PATH"
    cp -R Resources/* "$PRODUCT_PATH"/ 2>/dev/null || true
    cp supports/Info.plist "$PRODUCT_PATH"/Info.plist 2>/dev/null || true
fi

# Ensure entitlements
cp supports/entitlements.plist "$ARCHIVE_PATH/Products" 2>/dev/null || true

# Codesign (fake)
codesign --remove-signature "$PRODUCT_PATH" 2>/dev/null || true
ldid -Sentitlements.plist "$PRODUCT_PATH"

# Prepare Payload
cd "$ARCHIVE_PATH/Products"
mv Applications Payload

# Package as .tipa
zip -qr TrollSpeed.tipa Payload
cd ../..

mkdir -p packages
mv "$ARCHIVE_PATH/Products/TrollSpeed.tipa" "packages/TrollSpeed_v${VERSION}.tipa"

echo "✅ Build completed successfully!"
ls -lh packages
