#!/bin/bash
set -euo pipefail
release_prop() {
	bundle exec xcodeproj show --format=tree_hash | yq e '.rootObject.targets[]|select(.name=="NXBoot")|.buildConfigurationList.buildConfigurations[]|select(.name=="Release")|.buildSettings.'$1 -
}
projdir=$PWD
version=$(release_prop MARKETING_VERSION)
buildno=$(release_prop CURRENT_PROJECT_VERSION)
bindir=$projdir/DerivedData/bin
mkdir -p "$bindir/"{iphoneos,macos}
xcodebuild -scheme NXBootKit -configuration Release build | bundle exec xcpretty
target_ios=12.0
cflags="-DNXBOOT_VERSION=\"$version\" -DNXBOOT_BUILDNO=$buildno -D__OPEN_SOURCE__=1 -I$projdir/NXBootKit -std=gnu11 -fobjc-arc -fobjc-weak -fmodules -fvisibility=hidden -Wall -O2"
fwkflags="-framework CoreFoundation -framework Foundation -framework IOKit"
fwkflags_ios="$fwkflags -isystem $projdir/System/Include -iframework $projdir/System/Frameworks-iphoneos"
ldflags="-sectcreate __TEXT __intermezzo $projdir/Shared/Payloads/intermezzo.bin"
ldflags_macos="$ldflags DerivedData/NXBoot/Build/Products/Release/libNXBootKit_macOS.a"
ldflags_ios="$ldflags DerivedData/NXBoot/Build/Products/Release-iphoneos/libNXBootKit_iOS.a"

xcrun -sdk iphoneos clang NXBootCmd/main.m $cflags $fwkflags_ios $ldflags_ios -arch arm64 -miphoneos-version-min=$target_ios -o $bindir/iphoneos/nxboot
jtool --sign --inplace --ident com.mologie.NXBootCmd --ent NXBootCmd/NXBootCmd.entitlements $bindir/iphoneos/nxboot
echo "iOS executable available at $bindir/iphoneos/nxboot"

clang NXBootCmd/main.m $cflags $fwkflags $ldflags_macos -arch x86_64 -mmacosx-version-min=10.10 -o $bindir/macos/nxboot.x86_64
clang NXBootCmd/main.m $cflags $fwkflags $ldflags_macos -arch arm64 -mmacosx-version-min=11.0 -o $bindir/macos/nxboot.arm64
lipo -create -output $bindir/macos/nxboot $bindir/macos/nxboot.*
echo "Universal macOS executable available at $bindir/macos/nxboot"
