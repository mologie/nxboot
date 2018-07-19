#!/bin/bash
set -e
set -o pipefail

PROJDIR=$PWD
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" NXBoot/Info.plist)
buildno=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" NXBoot/Info.plist)
archivedest=$PROJDIR/dist/com.mologie.NXBoot-$version-$buildno
RELEASEDIR_MACOS=$PROJDIR/DerivedData/NXBoot/Build/Products/Release
RELEASEDIR_IOS=$PROJDIR/DerivedData/NXBoot/Build/Products/Release-iphoneos
BINDIR=$PROJDIR/DerivedData/bin
mkdir -p $PROJDIR/dist $BINDIR

echo "Building iOS application..."
xcodebuild -workspace NXBoot.xcworkspace -scheme NXBoot -configuration Release clean build | xcpretty
xcodebuild -workspace NXBoot.xcworkspace -scheme NXBootLegacy -configuration Release build | xcpretty

echo "Signing iOS application..."
rm -f $RELEASEDIR_IOS/NXBoot.app/embedded.mobileprovision
binpath=$RELEASEDIR_IOS/NXBoot.app/NXBoot
for arch in armv7 arm64; do
  lipo $binpath -thin $arch -output $binpath.$arch
  jtool --sign --inplace --ident com.mologie.NXBoot --ent NXBoot/NXBootJailbreak.entitlements $RELEASEDIR_IOS/NXBoot.app/NXBoot.$arch
done
lipo -create -output $binpath $binpath.armv7 $binpath.arm64
rm $binpath.*

#echo "Creating iOS app archiv archive..."
#(cd $RELEASEDIR_IOS && gtar -czf $archivedest.tar.gz --owner=0 --group=80 NXBoot.app)

echo "Creating iOS symbols archive..."
(cd $RELEASEDIR_IOS && zip -ry9 $archivedest.dSYM.zip NXBoot.app.dSYM)

echo "Building nxboot universal binary..."
./build_cmdtool.sh

echo "Building DEB package..."
echo "(This may prompt for your user password, which is required for prepading the Debian package where files are owned by root.)"
sudo ./build_deb.sh $(id -u) $(id -g) $version $buildno

echo "All done, the iOS app is available at: $archivedest.{deb,dSYM.zip}"
