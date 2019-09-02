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
xcodebuild -workspace NXBoot.xcworkspace -scheme NXBootKitAll -configuration Release build | xcpretty
NXBOOT_VER_IOS=7.0
NXBOOT_VER_MACOS=10.10
NXBOOT_CMD_CFLAGS="-DNXBOOT_VERSION=\"$version\" -DNXBOOT_BUILDNO=$buildno -I$PROJDIR/NXBootKit -std=gnu11 -fobjc-arc -fobjc-weak -fmodules -fvisibility=hidden -Wall -O2"
NXBOOT_CMD_FRAMEWORKS_IOS="-isystem $PROJDIR/System/Include -iframework $PROJDIR/System/Frameworks"
NXBOOT_CMD_FRAMEWORKS="-framework CoreFoundation -framework Foundation -framework IOKit"
NXBOOT_CMD_LDFLAGS="-lNXBootKit -sectcreate __TEXT __intermezzo $PROJDIR/Shared/Payloads/intermezzo.bin"
xcrun -sdk iphoneos clang NXBootCmd/main.m $NXBOOT_CMD_CFLAGS $NXBOOT_CMD_FRAMEWORKS_IOS $NXBOOT_CMD_FRAMEWORKS -L"$RELEASEDIR_IOS" $NXBOOT_CMD_LDFLAGS -arch armv7 -miphoneos-version-min=$NXBOOT_VER_IOS -o $BINDIR/nxboot.armv7
jtool --sign --inplace --ident com.mologie.NXBootCmd --ent NXBootCmd/NXBootCmd.entitlements $BINDIR/nxboot.armv7
xcrun -sdk iphoneos clang NXBootCmd/main.m $NXBOOT_CMD_CFLAGS $NXBOOT_CMD_FRAMEWORKS_IOS $NXBOOT_CMD_FRAMEWORKS -L"$RELEASEDIR_IOS" $NXBOOT_CMD_LDFLAGS -arch arm64 -miphoneos-version-min=$NXBOOT_VER_IOS -o $BINDIR/nxboot.arm64
jtool --sign --inplace --ident com.mologie.NXBootCmd --ent NXBootCmd/NXBootCmd.entitlements $BINDIR/nxboot.arm64
clang NXBootCmd/main.m $NXBOOT_CMD_CFLAGS $NXBOOT_CMD_FRAMEWORKS "-L$RELEASEDIR_MACOS" $NXBOOT_CMD_LDFLAGS -arch x86_64 -mmacosx-version-min=$NXBOOT_VER_MACOS -o $BINDIR/nxboot.x86_64
lipo -create -output $BINDIR/nxboot $BINDIR/nxboot.*
echo "Universal executable available at $BINDIR/nxboot"
