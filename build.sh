#!/bin/sh

# This script builds the Polin app and creates a .tipa package (for TrollStore)
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION=$1
VERSION=${VERSION#v} # Remove leading 'v' if present

# Clean and archive using Xcode
xcodebuild clean build archive \
  -scheme Polin \
  -project Polin.xcodeproj \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath Polin.xarchive \
  CODE_SIGNING_ALLOWED=NO | xcpretty

# Ensure important files have correct permissions
chmod 0644 Resources/Info.plist 2>/dev/null || true
chmod 0644 supports/Sandbox-Info.plist 2>/dev/null || true

# Copy entitlements to archive products
cp supports/entitlements.plist Polin.xarchive/Products 2>/dev/null || true

# Move into archive to prepare Payload
cd Polin.xarchive/Products/Applications || exit 1
codesign --remove-signature Polin.app 2>/dev/null || true
cd ..

# Rename folder to Payload for packaging
mv Applications Payload

# Sign the app with ldid using entitlements
ldid -Sentitlements.plist Payload/Polin.app

# Fix permissions and package as .tipa
chmod 0644 Payload/Polin.app/Info.plist
zip -qr Polin.tipa Payload

# Move final build to packages folder
cd ../..
mkdir -p packages
mv Polin.xarchive/Products/Polin.tipa packages/Polin+AppIntents16_${VERSION}.tipa

echo "✅ Build completed successfully: packages/Polin+AppIntents16_${VERSION}.tipa"
