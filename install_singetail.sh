#!/bin/sh
set -e
set -o pipefail

device=singetail

echo Building...
./build.sh
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" MobileFuseeLauncher/Info.plist)
archivedest=dist/NXBoot-$version.tar.gz

echo Cleaning...
ssh root@$device rm -rf /jb/bin/nxboot /Applications/NXBoot.app
ssh root@$device killall NXBoot || true

echo Installing nxboot command-line tool...
scp nxboot root@$device:/jb/bin/nxboot

echo Installing iOS application $version
cat $archivedest | ssh root@$device tar -C /Applications -xz

echo Done! You may want to run uicache on $device.
