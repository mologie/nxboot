#!/bin/bash
set -e
set -o pipefail

ORIG_UID=$1
ORIG_GID=$2
version=$3

rm -rf build/dpkg/
mkdir -p build/dpkg/com.mologie.NXBoot/{DEBIAN,Applications}
cat control | sed "s/Version: X\.Y\.Z/Version: $version/" > build/dpkg/com.mologie.NXBoot/DEBIAN/control
rsync -a build/Release-iphoneos/NXBoot.app build/dpkg/com.mologie.NXBoot/Applications/

cd build/dpkg/
chown -R 0:80 .
dpkg-deb -Zgzip -b com.mologie.NXBoot ../../dist/com.mologie.NXBoot-$version.deb
chown $ORIG_UID:$ORIG_GID ../../dist/com.mologie.NXBoot-$version.deb
chown -R $ORIG_UID:$ORIG_GID .
cd ../../

echo Done building DEB.
