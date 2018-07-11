#!/bin/sh
set -e
set -o pipefail

device=singetail
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" MobileFuseeLauncher/Info.plist)
buildno=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" MobileFuseeLauncher/Info.plist)
archivedest=

echo Cleaning...
ssh root@$device rm -f /jb/bin/nxboot
ssh root@$device killall NXBoot || true

echo Installing nxboot command-line tool...
scp nxboot root@$device:/jb/bin/nxboot

echo Installing iOS application $version via dpkg...
debname=com.mologie.NXBoot-$version-$buildno.deb
scp dist/$debname root@$device:/tmp/$debname
ssh root@$device dpkg -i /tmp/$debname

echo Done! You may want to run uicache on $device.
