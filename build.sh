#!/bin/bash
# Builds DemoLoop (armv7, iOS 6.0+) into a .deb without Theos or Xcode.
#
# Needs: an iOS clang/ld/ldid toolchain (e.g. the one Theos downloads),
#        iPhoneOS9.3.sdk (https://github.com/theos/sdks) and dpkg-deb.
#
#   TOOLCHAIN=/path/to/toolchain/linux/iphone SDK=/path/to/iPhoneOS9.3.sdk ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

: "${TOOLCHAIN:?set TOOLCHAIN to the folder that contains bin/clang, bin/ld and bin/ldid}"
: "${SDK:?set SDK to the path of iPhoneOS9.3.sdk}"
export PATH="$TOOLCHAIN/bin:$PATH"

VERSION=$(sed -n 's/^Version: //p' control)
OUT=build
PKG=$OUT/pkg
APP=$PKG/Applications/DemoLoop.app
rm -rf "$OUT"
mkdir -p "$APP" "$PKG/DEBIAN"

# The SDK from theos/sdks lacks this stub, but libSystem.tbd re-exports it,
# so the linker fails without it. Create it once.
STUB="$SDK/usr/lib/system/liblaunch.tbd"
if [ ! -f "$STUB" ]; then
  echo "creating $STUB"
  cat > "$STUB" <<'EOF'
---
archs:                 [ armv7, armv7s, arm64, i386, x86_64 ]
platform:              ios
install-name:          /usr/lib/system/liblaunch.dylib
current-version:       1
compatibility-version: 1
exports:
  - archs:              [ armv7, armv7s, arm64, i386, x86_64 ]
    symbols:            [ _launch_data_free ]
...
EOF
fi

clang -target armv7-apple-ios6.0 -isysroot "$SDK" -fobjc-arc -fblocks -O2 -Wall \
      -Wno-deprecated-declarations -c main.m -o "$OUT/main.o"

ld -arch armv7 -ios_version_min 6.0.0 -syslibroot "$SDK" -o "$APP/DemoLoop" "$OUT/main.o" \
   -framework UIKit -framework Foundation -framework AVFoundation -framework CoreMedia \
   -framework QuartzCore -framework CoreGraphics -framework MobileCoreServices -lobjc -lSystem -dead_strip \
   > "$OUT/ld.log" 2>&1 || true
grep -v -E 'linking in .tbd file|is deprecated' "$OUT/ld.log" || true
[ -f "$APP/DemoLoop" ] || { echo "link failed, see $OUT/ld.log"; exit 1; }

ldid -S "$APP/DemoLoop"

cp Resources/* "$APP/"
cp -R layout/. "$PKG/"
cp control "$PKG/DEBIAN/control"
chmod 755 "$APP/DemoLoop" "$PKG/DEBIAN/postinst" "$PKG/DEBIAN/prerm" "$PKG/usr/libexec/demoloop-launcher"
chmod 644 "$APP"/*.png "$APP/Info.plist" "$PKG"/Library/LaunchDaemons/*.plist
chmod 755 "$PKG/Library/Application Support" "$PKG/Library/Application Support/DemoLoop"

DEB="$OUT/com.demoloop.app_${VERSION}_iphoneos-arm.deb"
dpkg-deb --root-owner-group -Zgzip -b "$PKG" "$DEB"
echo "built: $DEB"
