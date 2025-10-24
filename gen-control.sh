#!/bin/sh

# This script generates the DEBIAN/control file and updates Info.plist for the Polin app.
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION=$1
VERSION=${VERSION#v} # Strip leading 'v' if present

# Create layout directory for Debian package
mkdir -p layout/DEBIAN

# Write the control file
cat > layout/DEBIAN/control << __EOF__
Package: ch.xxtou.polin.jb
Name: Polin JB
Version: $VERSION
Section: Tweaks
Depends: firmware (>= 14.0)
Architecture: iphoneos-arm
Author: Shshsjsisjsj <support@polin.dev>
Maintainer: Shshsjsisjsj <support@polin.dev>
Description: Polin — Dynamic TrollStore & Jailbreak utility.
__EOF__

# Set proper permissions
chmod 0644 layout/DEBIAN/control

# Generate random build number
RAND_BUILD_STR=$(openssl rand -hex 4)

# Update app Info.plist and Sandbox Info.plist
if [ -f "$PWD/Resources/Info.plist" ]; then
    defaults write "$PWD/Resources/Info.plist" CFBundleShortVersionString "$VERSION"
    defaults write "$PWD/Resources/Info.plist" CFBundleVersion "$RAND_BUILD_STR"
    plutil -convert xml1 "$PWD/Resources/Info.plist"
    chmod 0644 "$PWD/Resources/Info.plist"
fi

if [ -f "$PWD/supports/Sandbox-Info.plist" ]; then
    defaults write "$PWD/supports/Sandbox-Info.plist" CFBundleShortVersionString "$VERSION"
    defaults write "$PWD/supports/Sandbox-Info.plist" CFBundleVersion "$RAND_BUILD_STR"
    plutil -convert xml1 "$PWD/supports/Sandbox-Info.plist"
    chmod 0644 "$PWD/supports/Sandbox-Info.plist"
fi

# Update Xcode project version number
XCODE_PROJ_PBXPROJ="$PWD/Polin.xcodeproj/project.pbxproj"
if [ -f "$XCODE_PROJ_PBXPROJ" ]; then
    sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $VERSION;/g" "$XCODE_PROJ_PBXPROJ"
fi

echo "✅ Generated DEBIAN/control and updated version info successfully!"
