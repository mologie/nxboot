#!/bin/bash
set -euo pipefail
release_prop() {
	bundle exec xcodeproj show --format=tree_hash | yq e '.rootObject.targets[]|select(.name=="NXBoot")|.buildConfigurationList.buildConfigurations[]|select(.name=="Release")|.buildSettings.'$1 -
}

projdir=$(dirname "$0")
version=$(release_prop MARKETING_VERSION)
buildno=$(release_prop CURRENT_PROJECT_VERSION)
distdir=$projdir/dist
tmpdir=$projdir/DerivedData/bin
mkdir -p {"$distdir","$tmpdir"}/{iphoneos,macos}
srcs=(NXBootCmd/*.m NXBootKit/*.m)
cflags=(-DNXBOOT_VERSION=\"$version\" -DNXBOOT_BUILDNO=$buildno -D__OPEN_SOURCE__=1 -I"$projdir" -I"$projdir/NXBootKit" -std=gnu11 -fobjc-arc -fobjc-weak -fmodules -fvisibility=hidden -Wall -O2)
fwkflags=(-framework CoreFoundation -framework Foundation -framework IOKit)
fwkflags_ios=("${fwkflags[@]}" -isystem "$projdir/System/include" -iframework "$projdir/System/Frameworks-iphoneos")
ldflags=(-sectcreate __TEXT __intermezzo "$projdir/Shared/Payloads/intermezzo.bin" -L"$projdir/System/lib")

xcrun -sdk iphoneos clang "${srcs[@]}" "${cflags[@]}" "${fwkflags_ios[@]}" "${ldflags[@]}" -arch armv7 -miphoneos-version-min=5.0 -o "$tmpdir/iphoneos/nxboot.armv7"
xcrun -sdk iphoneos clang "${srcs[@]}" "${cflags[@]}" "${fwkflags_ios[@]}" "${ldflags[@]}" -arch arm64 -miphoneos-version-min=7.0 -o "$tmpdir/iphoneos/nxboot.arm64"
jtool --sign --inplace --ident com.mologie.NXBootCmd --ent NXBootCmd/NXBootCmd.entitlements "$tmpdir/iphoneos/nxboot.arm64"
lipo -create -output "$distdir/iphoneos/nxboot" "$tmpdir/iphoneos/nxboot".*
echo "iOS executable available at $distdir/iphoneos/nxboot"

clang "${srcs[@]}" "${cflags[@]}" "${fwkflags[@]}" "${ldflags[@]}" -arch x86_64 -mmacosx-version-min=10.7 -o "$tmpdir/macos/nxboot.x86_64"
clang "${srcs[@]}" "${cflags[@]}" "${fwkflags[@]}" "${ldflags[@]}" -arch arm64 -mmacosx-version-min=11.0 -o "$tmpdir/macos/nxboot.arm64"
lipo -create -output "$distdir/macos/nxboot" "$tmpdir/macos/nxboot".*
echo "Universal macOS executable available at $distdir/macos/nxboot"
