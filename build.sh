#!/bin/bash
set -e
set -o pipefail

PROJDIR=$PWD
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" MobileFuseeLauncher/Info.plist)
buildno=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" MobileFuseeLauncher/Info.plist)
archivedest=$PROJDIR/dist/com.mologie.NXBoot-$version-$buildno
RELEASEDIR=$PROJDIR/DerivedData/MobileFuseeLauncher/Build/Products/Release-iphoneos
mkdir -p $PROJDIR/dist

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
xcodebuild -workspace MobileFuseeLauncher.xcworkspace -scheme NXBoot -configuration Release clean build | xcpretty

echo "Signing..."
rm -f $RELEASEDIR/NXBoot.app/embedded.mobileprovision
binpath=$RELEASEDIR/NXBoot.app/NXBoot
for arch in armv7 arm64; do
    lipo $binpath -thin $arch -output $binpath.$arch
    jtool --sign --inplace --ident com.mologie.NXBoot --ent nxboot-app.entitlements $RELEASEDIR/NXBoot.app/NXBoot.$arch
done
lipo -create -output $binpath $binpath.armv7 $binpath.arm64
rm $binpath.*

echo "Creating iOS app archiv archive..."
(cd $RELEASEDIR && gtar -czf $archivedest.tar.gz --owner=0 --group=80 NXBoot.app)

echo "Creating symbols archive..."
(cd $RELEASEDIR && zip -ry9 $archivedest.dSYM.zip NXBoot.app.dSYM)

echo "Building DEB package..."
echo "(This may prompt for your user password, which is required for prepading the Debian package where files are owned by root.)"
sudo ./build_deb.sh $(id -u) $(id -g) $version $buildno

echo "All done, the iOS app is available at: $archivedest.{deb,tar.gz,dSYM.zip}"
