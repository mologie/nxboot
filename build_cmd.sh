#!/bin/bash
set -euo pipefail
release_prop() {
	bundle exec xcodeproj show --format=tree_hash | yq r - \
		"rootObject.targets(name==NXBoot).buildConfigurationList.buildConfigurations(name==Release).buildSettings.$1"
}
projdir=$PWD
version=$(release_prop MARKETING_VERSION)
buildno=$(release_prop CURRENT_PROJECT_VERSION)
bindir=$projdir/DerivedData/bin
mkdir -p "$bindir"
xcodebuild -scheme NXBootKit -configuration Release build | bundle exec xcpretty
target_ios=7.0
target_macos=10.10
cflags="-DNXBOOT_VERSION=\"$version\" -DNXBOOT_BUILDNO=$buildno -D__OPEN_SOURCE__=1 -I$projdir/NXBootKit -std=gnu11 -fobjc-arc -fobjc-weak -fmodules -fvisibility=hidden -Wall -O2"
fwkflags="-framework CoreFoundation -framework Foundation -framework IOKit"
fwkflags_ios="$fwkflags -isystem $projdir/System/Include -iframework $projdir/System/Frameworks-iphoneos"
ldflags="-sectcreate __TEXT __intermezzo $projdir/Shared/Payloads/intermezzo.bin"
ldflags_macos="$ldflags DerivedData/NXBoot/Build/Products/Release/libNXBootKit_macOS.a"
ldflags_ios="$ldflags DerivedData/NXBoot/Build/Products/Release-iphoneos/libNXBootKit_iOS.a"
xcrun -sdk iphoneos clang NXBootCmd/main.m $cflags $fwkflags_ios $ldflags_ios -arch armv7 -miphoneos-version-min=$target_ios -o $bindir/nxboot.armv7
jtool --sign --inplace --ident com.mologie.NXBootCmd --ent NXBootCmd/NXBootCmd.entitlements $bindir/nxboot.armv7
xcrun -sdk iphoneos clang NXBootCmd/main.m $cflags $fwkflags_ios $ldflags_ios -arch arm64 -miphoneos-version-min=$target_ios -o $bindir/nxboot.arm64
jtool --sign --inplace --ident com.mologie.NXBootCmd --ent NXBootCmd/NXBootCmd.entitlements $bindir/nxboot.arm64
clang NXBootCmd/main.m $cflags $fwkflags $ldflags_macos -arch x86_64 -mmacosx-version-min=$target_macos -o $bindir/nxboot.x86_64
lipo -create -output $bindir/nxboot $bindir/nxboot.*
echo "Universal executable available at $bindir/nxboot"
