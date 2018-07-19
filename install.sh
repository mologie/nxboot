#!/bin/sh
set -e
set -o pipefail

if [ -z "$1" ]; then
    echo "Usage: $0 <device>"
    exit 1
fi

device=$1
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" NXBoot/Info.plist)
buildno=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" NXBoot/Info.plist)
archivedest=

echo Installing version $version via dpkg...
debname=com.mologie.NXBoot-$version-$buildno.deb
scp dist/$debname root@$device:/tmp/$debname
ssh root@$device dpkg -i /tmp/$debname

echo Done! You may want to run uicache on $device.
