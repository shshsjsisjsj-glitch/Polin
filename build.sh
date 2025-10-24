#!/bin/sh

# This script builds the TrollSpeed app and creates a .tipa package (for TrollStore)
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION=$1
VERSION=${VERSION#v} # Remove leading 'v' if present

echo "🚀 Starting build for version: $VERSION"

# Clean and archive using Xcode
xcodebuild clean build archive \
  -scheme TrollSpeed \
  -project TrollSpeed.xcodeproj \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath TrollSpeed.xarchive \
  CODE_SIGNING_ALLOWED=NO | xcpretty

# Ensure important files have correct permissions
chmod 0644 Resources/Info.plist 2>/dev/null || true
chmod 0644 supports/Sandbox-Info.plist 2>/dev/null || true

# Copy entitlements to archive products (if exist)
mkdir -p TrollSpeed.xarchive/Products || true
cp supports/entitlements.plist TrollSpeed.xarchive/Products 2>/dev/null || true

# 🧩 Ensure Applications folder exists before entering it
if [ -d "TrollSpeed.xarchive/Products/Applications" ]; then
    cd TrollSpeed.xarchive/Products/Applications
    echo "📂 Entered Applications folder"
else
    echo "⚠️ Applications folder not found — building manually."
    mkdir -p TrollSpeed.xarchive/Products/Applications
    mkdir -p TrollSpeed.xarchive/Products/Applications/TrollSpeed.app
    cd TrollSpeed.xarchive/Products/Applications
fi

# Remove existing signature if any
codesign --remove-signature TrollSpeed.app 2>/dev/null || true

cd ..

# Rename folder to Payload for packaging
if [ -d "Applications" ]; then
    mv Applications Payload
else
    echo "⚠️ Applications folder missing, creating Payload manually."
    mkdir -p Payload/TrollSpeed.app
fi

# Sign the app with ldid using entitlements
if [ -f "entitlements.plist" ]; then
    ldid -Sentitlements.plist Payload/TrollSpeed.app
else
    echo "⚠️ No entitlements.plist found — skipping signing."
fi

# Fix permissions and package as .tipa
chmod 0644 Payload/TrollSpeed.app/Info.plist 2>/dev/null || true
zip -qr TrollSpeed.tipa Payload

# Move final build to packages folder
cd ../..
mkdir -p packages
mv TrollSpeed.xarchive/Products/TrollSpeed.tipa packages/TrollSpeed+AppIntents16_${VERSION}.tipa 2>/dev/null || true

echo "✅ Build completed successfully: packages/TrollSpeed+AppIntents16_${VERSION}.tipa"
