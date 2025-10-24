#!/bin/sh
set -e

# ==============================================================
# 🚀 TrollSpeed Build Script (For GitHub Actions + TrollStore)
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

# ==============================================================
# 🧹 Clean and archive (ignore Xcode failure, fallback manual)
# ==============================================================

xcodebuild clean build archive \
  -scheme "$APP_NAME" \
  -project "$APP_NAME.xcodeproj" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGNING_ALLOWED=NO | xcpretty || true

mkdir -p "$PRODUCT_PATH"

# ==============================================================
# 🧩 Manual compilation fallback
# ==============================================================

if [ ! -f "$PRODUCT_PATH/$APP_NAME" ]; then
    echo "⚠️ No main binary found — compiling sources manually..."
    echo "🔍 Searching for .m / .mm / .cpp files in sources/"

    SRC_FILES=$(find "$PWD/sources" -type f \( -name "*.m" -o -name "*.mm" -o -name "*.cpp" \))
    COUNT=$(echo "$SRC_FILES" | wc -l)
    echo "📦 Found $COUNT source files."

    if [ "$COUNT" -eq 0 ]; then
        echo "❌ No source files found! Check sources/ path."
        exit 1
    fi

    echo "🧠 Starting manual compile (using clang++)..."
    clang++ -isysroot "$(xcrun --sdk iphoneos --show-sdk-path)" \
        -arch arm64 \
        -std=c++17 \
        -fobjc-arc -fobjc-runtime=ios-14.0 \
        -fobjc-abi-version=2 \
        -fvisibility=hidden \
        -fvisibility-inlines-hidden \
        -I"$PWD/sources" \
        -I"$PWD/sources/ImGui" \
        -I"$PWD/sources/Polin/ImGui" \
        -framework UIKit \
        -framework Foundation \
        -framework Metal \
        -framework QuartzCore \
        -framework CoreGraphics \
        -framework CoreAnimation \
        -o "$PRODUCT_PATH/$APP_NAME" $SRC_FILES 2>&1 | tee compile.log || true

    if [ -f "$PRODUCT_PATH/$APP_NAME" ]; then
        chmod +x "$PRODUCT_PATH/$APP_NAME"
        echo "✅ Manual compile successful!"
    else
        echo "❌ Manual compilation failed: binary not found."
        echo "🧾 Check compile.log for detailed output."
        exit 1
    fi
fi

# ==============================================================
# 🧾 Generate Info.plist if missing
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
# 📦 Copy Resources and sign app
# ==============================================================

echo "📂 Copying resources..."
[ -d "Resources" ] && cp -R Resources "$PRODUCT_PATH"/
[ -d "ImGui" ] && cp -R ImGui "$PRODUCT_PATH"/
[ -d "supports" ] && cp -R supports "$PRODUCT_PATH"/

# Copy entitlements (optional)
cp supports/entitlements.plist "$ARCHIVE_PATH/Products" 2>/dev/null || true

echo "🔏 Signing binary..."
if [ -f "$PRODUCT_PATH/$APP_NAME" ]; then
    if [ -f "$ARCHIVE_PATH/Products/entitlements.plist" ]; then
        ldid -S"$ARCHIVE_PATH/Products/entitlements.plist" "$PRODUCT_PATH/$APP_NAME" || true
    else
        ldid -Sentitlements.plist "$PRODUCT_PATH/$APP_NAME" 2>/dev/null || true
    fi
fi

# ==============================================================
# 🧩 Package as .tipa for TrollStore
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
