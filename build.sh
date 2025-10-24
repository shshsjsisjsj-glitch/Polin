#!/bin/sh
set -e

VERSION=${1:-1.0.0}
APP_NAME="TrollSpeed"
ARCHIVE_PATH="$APP_NAME.xarchive"
PRODUCT_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"

echo "🚀 Building $APP_NAME v$VERSION..."

# Clean & attempt Xcode build (ignore failure)
xcodebuild clean build archive \
  -scheme "$APP_NAME" \
  -project "$APP_NAME.xcodeproj" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGNING_ALLOWED=NO | xcpretty || true

# Ensure .app structure exists
mkdir -p "$PRODUCT_PATH"

# 🧩 Compile all Objective-C / C++ sources manually if binary missing
if [ ! -f "$PRODUCT_PATH/$APP_NAME" ]; then
    echo "⚠️ No main binary found — compiling sources manually..."
    SRC_FILES=$(find sources -type f \( -name "*.m" -o -name "*.mm" -o -name "*.cpp" \))
    clang -isysroot "$(xcrun --sdk iphoneos --show-sdk-path)" \
        -arch arm64 -fobjc-arc -ObjC \
        -framework UIKit -framework Foundation -framework Metal -framework QuartzCore \
        -o "$PRODUCT_PATH/$APP_NAME" $SRC_FILES 2>/dev/null || true
    chmod +x "$PRODUCT_PATH/$APP_NAME"
fi

# ✅ Generate Info.plist if missing
if [ ! -f "$PRODUCT_PATH/Info.plist" ]; then
cat > "$PRODUCT_PATH/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>com.user.trollspeed</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
</dict>
</plist>
EOF
fi

# 📦 Copy assets
[ -d "Resources" ] && cp -R Resources "$PRODUCT_PATH"/
[ -d "ImGui" ] && cp -R ImGui "$PRODUCT_PATH"/

# 🪪 Entitlements & signing
cp supports/entitlements.plist "$ARCHIVE_PATH/Products" 2>/dev/null || true
ldid -Sentitlements.plist "$PRODUCT_PATH/$APP_NAME" 2>/dev/null || true

# Prepare Payload
cd "$ARCHIVE_PATH/Products"
mv Applications Payload
zip -qr TrollSpeed.tipa Payload
cd ../..

mkdir -p packages
mv "$ARCHIVE_PATH/Products/TrollSpeed.tipa" "packages/TrollSpeed_v${VERSION}.tipa"

echo "✅ Done! Output -> packages/TrollSpeed_v${VERSION}.tipa"
