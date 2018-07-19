#!/bin/bash
set -e
set -o pipefail
PROJDIR=$PWD
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" NXBoot/Info.plist)
buildno=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" NXBoot/Info.plist)
RELEASEDIR_MACOS=$PROJDIR/DerivedData/NXBoot/Build/Products/Release
RELEASEDIR_IOS=$PROJDIR/DerivedData/NXBoot/Build/Products/Release-iphoneos
BINDIR=$PROJDIR/DerivedData/bin
mkdir -p $BINDIR
xcodebuild -workspace NXBoot.xcworkspace -scheme NXBootKit -configuration Release build | xcpretty
xcodebuild -workspace NXBoot.xcworkspace -scheme NXBootKitMac -configuration Release build | xcpretty
NXBOOT_CMD_CFLAGS="-DNXBOOT_VERSION=\"$version\" -DNXBOOT_BUILDNO=$buildno -I$PROJDIR/NXBootKit -std=gnu11 -fobjc-arc -fobjc-weak -fmodules -fvisibility=hidden -Wall -O2"
NXBOOT_CMD_FRAMEWORKS="-framework CoreFoundation -framework Foundation -framework IOKit"
xcrun -sdk iphoneos clang NXBootCmd/main.m $NXBOOT_CMD_CFLAGS $NXBOOT_CMD_FRAMEWORKS "-L$RELEASEDIR_IOS" -lNXBootKit -arch armv7 -miphoneos-version-min=7.0 -o $BINDIR/nxboot.armv7
xcrun -sdk iphoneos clang NXBootCmd/main.m $NXBOOT_CMD_CFLAGS $NXBOOT_CMD_FRAMEWORKS "-L$RELEASEDIR_IOS" -lNXBootKit -arch arm64 -miphoneos-version-min=7.0 -o $BINDIR/nxboot.arm64
jtool --sign --inplace --ident com.mologie.NXBootCmd --ent NXBootCmd/NXBootCmd.entitlements $BINDIR/nxboot.armv7
jtool --sign --inplace --ident com.mologie.NXBootCmd --ent NXBootCmd/NXBootCmd.entitlements $BINDIR/nxboot.arm64
clang NXBootCmd/main.m $NXBOOT_CMD_CFLAGS $NXBOOT_CMD_FRAMEWORKS "-L$RELEASEDIR_MACOS" -lNXBootKit -arch x86_64 -mmacosx-version-min=10.10 -o $BINDIR/nxboot.x86_64
lipo -create -output $BINDIR/nxboot $BINDIR/nxboot.*
echo "Universal executable available at $BINDIR/nxboot"
