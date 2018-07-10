#!/bin/bash
set -e
set -o pipefail

echo "Building nxboot binary..."
SRCS="nxboot.m"
CFLAGS="-std=gnu11 -fobjc-arc -fobjc-weak -fmodules -Wall -O2"
FRMWKS="-framework CoreFoundation -framework Foundation -framework IOKit"
xcrun -sdk iphoneos clang $SRCS $CFLAGS -arch arm64 -o .nxboot_arm64
jtool --sign --inplace --ident com.mologie.NXBootCmd --ent nxboot-cmd.entitlements .nxboot_arm64
clang $SRCS $CFLAGS -arch x86_64 -o .nxboot_x86_64
lipo -create -output nxboot .nxboot_arm64 .nxboot_x86_64
rm .nxboot_arm64 .nxboot_x86_64

echo "Building iOS application..."
xcodebuild -configuration Release clean build | xcpretty

echo "Signing..."
rm -f build/Release-iphoneos/NXBoot.app/embedded.mobileprovision
binpath=build/Release-iphoneos/NXBoot.app/NXBoot
for arch in armv7 arm64; do
    lipo $binpath -thin $arch -output $binpath.$arch
    jtool --sign --inplace --ident com.mologie.NXBoot --ent nxboot-app.entitlements build/Release-iphoneos/NXBoot.app/NXBoot.$arch
done
lipo -create -output $binpath $binpath.armv7 $binpath.arm64
rm $binpath.*

echo "Creating iOS app archiv archive..."
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" MobileFuseeLauncher/Info.plist)
archivedest=dist/com.mologie.NXBoot-$version.tar.gz
mkdir -p dist
(cd build/Release-iphoneos/ && gtar -czf ../../$archivedest --owner=0 --group=80 NXBoot.app)

echo "Building DEB package..."
echo "(This may prompt for your user password, which is required for prepading the Debian package where files are owned by root.)"
sudo ./build_deb.sh $(id -u) $(id -g) $version

echo "All done, the iOS app is available at: $archivedest"
