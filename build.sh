#!/bin/sh
set -e

# ==============================================================
# ✅ TrollSpeed Build Script (GitHub Actions / TrollStore)
# ==============================================================

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION=$1
VERSION=${VERSION#v}
APP_NAME="TrollSpeed"

ARCHIVE_PATH="$APP_NAME.xarchive"
PRODUCT_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"

echo "🚀 Building $APP_NAME v$VERSION..."
echo "==========================================="

# Clean & archive (ignore Xcode failure to continue manual build)
xcodebuild clean build archive \
  -scheme "$APP_NAME" \
  -project "$APP_NAME.xcodeproj" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGNING_ALLOWED=NO | xcpretty || true

# Create app structure
mkdir -p "$PRODUCT_PATH"

# ==============================================================
# 🧩 MANUAL COMPILATION (Fallback)
# ==============================================================

if [ ! -f "$PRODUCT_PATH/$APP_NAME" ]; then
    echo "⚠️ No main binary found — compiling sources manually..."
    echo "🔍 Searching for .m / .mm / .cpp files in sources/"

    # Detect all sources automatically
    SRC_FILES=$(find "$PWD/sources" -type f \( -name "*.m" -o -name "*.mm" -o -name "*.cpp" \))
    echo "📦 Found $(echo "$SRC_FILES" | wc -l) source files."

    # Compile manually
    clang -isysroot "$(xcrun --sdk iphoneos --show-sdk-path)" \
        -arch arm64 -fobjc-arc -ObjC \
        -I"$PWD/sources" -I"$PWD/sources/ImGui" -I"$PWD/sources/Polin/ImGui" \
        -framework UIKit -framework Foundation -framework Metal -framework QuartzCore \
        -o "$PRODUCT_PATH/$APP_NAME" $SRC_FILES 2>/dev/null || true

    if [ -f "$PRODUCT_PATH/$APP_NAME" ]; then
        chmod +x "$PRODUCT_PATH/$APP_NAME"
        echo "✅ Manual binary compilation successful!"
    else
        echo "❌ Manual compilation failed: binary not found."
        exit 1
    fi
fi

# ==============================================================
# 🧾 GENERATE INFO.PLIST (if missing)
# ==============================================================

if [ ! -f "$PRODUCT_PATH/Info.plist" ]; then
    echo "📄 Generating Info.plist..."
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
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
</dict>
</plist>
EOF
fi

# ==============================================================
# 📦 COPY RESOURCES & SIGNING
# ==============================================================

echo "📂 Copying resources..."
[ -d "Resources" ] && cp -R Resources "$PRODUCT_PATH"/
[ -d "ImGui" ] && cp -R ImGui "$PRODUCT_PATH"/

# Copy entitlements if available
cp supports/entitlements.plist "$ARCHIVE_PATH/Products" 2>/dev/null || true

echo "🔏 Signing binary with ldid..."
ldid -Sentitlements.plist "$PRODUCT_PATH/$APP_NAME" 2>/dev/null || true

# ==============================================================
# 📦 PACKAGE AS .TIPA
# ==============================================================

echo "📦 Creating .tipa package..."
cd "$ARCHIVE_PATH/Products"
mv Applications Payload
zip -qr TrollSpeed.tipa Payload

cd ../..
mkdir -p packages
mv "$ARCHIVE_PATH/Products/TrollSpeed.tipa" "packages/TrollSpeed_v${VERSION}.tipa"

echo "✅ Build completed successfully!"
echo "📁 Output: packages/TrollSpeed_v${VERSION}.tipa"
echo "==========================================="
