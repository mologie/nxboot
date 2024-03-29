#!/bin/zsh
set -euo pipefail

target_property() {
  bundle exec xcodeproj show NXBoot.xcodeproj --no-ansi --format=tree_hash \
    | yj \
    | jq -r \
      '.rootObject.targets[]
      |select(.name=="NXBoot")
      |.buildConfigurationList.buildConfigurations[]
      |select(.name=="Release").buildSettings.'$1
}

version=$(target_property MARKETING_VERSION)
buildno=$(target_property CURRENT_PROJECT_VERSION)
bundleid=$(target_property PRODUCT_BUNDLE_IDENTIFIER)
distdir=dist
tmpdir=DerivedData/bin
releasedir=DerivedData/NXBoot/Build/Products/Release-iphoneos
mkdir -p {$distdir,$tmpdir}/{iphoneos,macos}

echo "Building iOS application for arm64..."
xcodebuild -scheme NXBoot -configuration Release -destination "generic/platform=iOS" clean build | bundle exec xcpretty
mv "$releasedir/NXBoot.app/NXBoot"{,.arm64}

echo "Building main binary for armv7..."
CoreDataGenerated=DerivedData/NXBoot/Build/Intermediates.noindex/NXBoot.build/Release-iphoneos/NXBoot.build/DerivedSources/CoreDataGenerated/Model
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang \
  -target armv7-apple-ios9.0 \
  -std=gnu11 \
  -isysroot "$(xcrun --show-sdk-path --sdk iphoneos)" \
  -iframework System/Frameworks-iphoneos \
  -isystem System/include \
  -I. \
  -INXBootKit \
  -I$CoreDataGenerated \
  -D__OPEN_SOURCE__=1 \
  -framework WebKit \
  -O2 \
  -Wall \
  -fmodules -fstrict-aliasing -fvisibility=hidden \
  -fobjc-arc -fobjc-weak -fobjc-link-runtime \
  -dead_strip \
  -Xlinker -reproducible \
  -Xlinker -export_dynamic \
  -Xlinker -no_deduplicate \
  -Xlinker -no_adhoc_codesign \
  -o DerivedData/NXBoot/Build/Products/Release-iphoneos/NXBoot.app/NXBoot.armv7 \
  NXBoot/*.m NXBootKit/*.m $CoreDataGenerated/*.m

echo "Signing iOS application..."
for arch in armv7 arm64; do
  ldid -I$bundleid -SNXBoot/NXBootJailbreak.entitlements "$releasedir/NXBoot.app/NXBoot.$arch"
done
lipo -create -output DerivedData/NXBoot/Build/Products/Release-iphoneos/NXBoot.app/NXBoot{,.armv7,.arm64}
rm DerivedData/NXBoot/Build/Products/Release-iphoneos/NXBoot.app/NXBoot.*
rm -f "$releasedir/NXBoot.app/embedded.mobileprovision"

echo "Building nxboot universal binary..."
cmd_srcs=(NXBootCmd/*.m NXBootKit/*.m)
cmd_cflags=(-DNXBOOT_VERSION=\"$version\" -DNXBOOT_BUILDNO=$buildno -D__OPEN_SOURCE__=1 -I. -INXBootKit -std=gnu11 -fobjc-arc -fobjc-weak -fmodules -fvisibility=hidden -Wall -O2)
cmd_fwkflags=(-framework CoreFoundation -framework Foundation -framework IOKit)
cmd_fwkflags_ios=("${cmd_fwkflags[@]}" -isystem System/include -iframework System/Frameworks-iphoneos)
cmd_ldflags=(-sectcreate __TEXT __intermezzo Shared/intermezzo.bin)
# iOS:
xcrun -sdk iphoneos clang "${cmd_srcs[@]}" "${cmd_cflags[@]}" "${cmd_fwkflags_ios[@]}" "${cmd_ldflags[@]}" -arch armv7 -arch arm64 -miphoneos-version-min=9.0 -o "$tmpdir/iphoneos/nxboot"
ldid -P "$tmpdir/iphoneos/nxboot"
install "$tmpdir/iphoneos/nxboot" "$distdir/iphoneos/nxboot"
echo "iOS executable available at $distdir/iphoneos/nxboot"
# macOS:
clang "${cmd_srcs[@]}" "${cmd_cflags[@]}" "${cmd_fwkflags[@]}" "${cmd_ldflags[@]}" -arch x86_64 -mmacosx-version-min=10.11 -o "$tmpdir/macos/nxboot.x86_64"
clang "${cmd_srcs[@]}" "${cmd_cflags[@]}" "${cmd_fwkflags[@]}" "${cmd_ldflags[@]}" -arch arm64 -mmacosx-version-min=11.0 -o "$tmpdir/macos/nxboot.arm64"
lipo -create -output "$distdir/macos/nxboot" "$tmpdir/macos/nxboot".*
echo "macOS executable available at $distdir/macos/nxboot"

echo "Building DEB package..."
echo "(This may prompt for your user password, which is required for prepading the Debian package where files are owned by root.)"
sudo env uid=$(id -u) gid=$(id -g) version=$version buildno=$buildno releasedir=$releasedir ./build_deb.sh

echo "Building IPA..."
rm -rf DerivedData/ipa
mkdir -p DerivedData/ipa/Payload
ditto DerivedData/NXBoot/Build/Products/Release-iphoneos/NXBoot.app DerivedData/ipa/Payload/NXBoot.app
(cd DerivedData/ipa && COPYFILE_DISABLE=1 zip -r "../../dist/iphoneos/NXBoot-$version-$buildno.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX")

echo "All done, the iOS app is available at dist/iphoneos/"
