#!/bin/sh
set -e

# ✅ Usage: ./gen-control.sh v1.0.0
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION=$1
VERSION=${VERSION#v} # Remove leading 'v'

echo "🧩 Generating Debian control files for version $VERSION..."

# Ensure layout exists
mkdir -p layout/DEBIAN

# Write DEBIAN/control
cat > layout/DEBIAN/control <<EOF
Package: ch.xxtou.hudapp.jb
Name: TrollSpeed JB
Version: $VERSION
Section: Tweaks
Depends: firmware (>= 14.0)
Architecture: iphoneos-arm
Author: Lessica <82flex@gmail.com>
Maintainer: Lessica <82flex@gmail.com>
Description: Troll your speed, but jailbroken version.
EOF

chmod 0644 layout/DEBIAN/control

# Create simple postinst script (optional)
cat > layout/DEBIAN/postinst <<EOF
#!/bin/sh
echo "[TrollSpeed] Installed successfully (v$VERSION)"
exit 0
EOF

chmod 0755 layout/DEBIAN/postinst

# Random build string for CFBundleVersion
RAND_BUILD_STR=$(openssl rand -hex 4)

# Update Info.plist (if exists)
if [ -f "$PWD/Resources/Info.plist" ]; then
    echo "📄 Updating Resources/Info.plist..."
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PWD/Resources/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$PWD/Resources/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $RAND_BUILD_STR" "$PWD/Resources/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $RAND_BUILD_STR" "$PWD/Resources/Info.plist"
fi

# Update Sandbox-Info.plist (if exists)
if [ -f "$PWD/supports/Sandbox-Info.plist" ]; then
    echo "📄 Updating supports/Sandbox-Info.plist..."
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PWD/supports/Sandbox-Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$PWD/supports/Sandbox-Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $RAND_BUILD_STR" "$PWD/supports/Sandbox-Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $RAND_BUILD_STR" "$PWD/supports/Sandbox-Info.plist"
fi

# Update version inside Xcode project
XCODE_PROJ="$PWD/TrollSpeed.xcodeproj/project.pbxproj"
if [ -f "$XCODE_PROJ" ]; then
    echo "🛠 Updating Xcode project version..."
    sed -i.bak "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $VERSION/" "$XCODE_PROJ" || true
fi

echo "✅ Control and plist generation completed successfully."
