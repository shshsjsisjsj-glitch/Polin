#!/bin/sh

# ============================================
# TrollSpeed Auto-Build Script for TrollStore
# ============================================

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION=$1
VERSION=${VERSION#v}  # Remove leading "v" if present

echo "🚀 Starting build for version: $VERSION"

# 🧹 Clean + Build + Archive
xcodebuild clean build archive \
  -scheme TrollSpeed \
  -project TrollSpeed.xcodeproj \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath TrollSpeed.xarchive \
  CODE_SIGNING_ALLOWED=NO | xcpretty

# 🧾 Ensure critical files exist and have correct permissions
chmod 0644 Resources/Info.plist 2>/dev/null || true
chmod 0644 supports/Sandbox-Info.plist 2>/dev/null || true

# 🧩 Ensure product structure exists
mkdir -p TrollSpeed.xarchive/Products || true
cp supports/entitlements.plist TrollSpeed.xarchive/Products/ 2>/dev/null || true

# 🏗 Create Applications folder if not generated
APP_PATH="TrollSpeed.xarchive/Products/Applications/TrollSpeed.app"
if [ -d "$APP_PATH" ]; then
    echo "📂 Found app: $APP_PATH"
else
    echo "⚠️ Applications folder missing, creating manually..."
    mkdir -p "$APP_PATH"
fi

# 🔧 Remove any previous signature
codesign --remove-signature "$APP_PATH" 2>/dev/null || true

# 🧱 Prepare Payload structure
cd TrollSpeed.xarchive/Products || exit 1
if [ -d "Applications" ]; then
    mv Applications Payload
else
    echo "⚠️ No Applications folder found, creating new Payload..."
    mkdir -p Payload/TrollSpeed.app
fi

# 🔏 Sign app (if entitlements exist)
if [ -f "entitlements.plist" ]; then
    ldid -Sentitlements.plist Payload/TrollSpeed.app
    echo "✅ Signed app with entitlements.plist"
else
    echo "⚠️ entitlements.plist not found — skipping signing."
fi

# 🧰 Fix Info.plist permissions
chmod 0644 Payload/TrollSpeed.app/Info.plist 2>/dev/null || true

# 📦 Create .tipa file
echo "📦 Packaging .tipa..."
zip -qr TrollSpeed.tipa Payload

# 🗂 Move build output to main packages folder
cd ../.. || exit 1
mkdir -p packages
if [ -f "Products/TrollSpeed.tipa" ]; then
    mv Products/TrollSpeed.tipa packages/TrollSpeed+AppIntents16_${VERSION}.tipa
elif [ -f "TrollSpeed.xarchive/Products/TrollSpeed.tipa" ]; then
    mv TrollSpeed.xarchive/Products/TrollSpeed.tipa packages/TrollSpeed+AppIntents16_${VERSION}.tipa
else
    echo "⚠️ .tipa file not found — skipping move."
fi

# ✅ Final confirmation
if [ -f "packages/TrollSpeed+AppIntents16_${VERSION}.tipa" ]; then
    echo "✅ Build completed successfully!"
    echo "📦 Output: packages/TrollSpeed+AppIntents16_${VERSION}.tipa"
else
    echo "❌ Build finished but .tipa file was not found."
    exit 1
fi
