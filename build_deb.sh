#!/bin/bash
set -e
set -o pipefail

ORIG_UID=$1
ORIG_GID=$2
version=$3
buildno=$4
DPKGDIR=DerivedData/dpkg
PROJDIR=$PWD
RELEASEDIR=$PROJDIR/DerivedData/MobileFuseeLauncher/Build/Products/Release-iphoneos

rm -rf $DPKGDIR
mkdir -p $DPKGDIR/com.mologie.NXBoot/{DEBIAN,Applications}
cat control | sed "s/Version: PLACEHOLDER/Version: $version-$buildno/" > $DPKGDIR/com.mologie.NXBoot/DEBIAN/control
rsync -a $RELEASEDIR/NXBoot.app $DPKGDIR/com.mologie.NXBoot/Applications/

cd $DPKGDIR
chown -R 0:80 .
dpkg-deb -Zgzip -b com.mologie.NXBoot $PROJDIR/dist/com.mologie.NXBoot-$version-$buildno.deb
chown $ORIG_UID:$ORIG_GID $PROJDIR/dist/com.mologie.NXBoot-$version-$buildno.deb
chown -R $ORIG_UID:$ORIG_GID .
cd $PROJDIR

echo Done building DEB.
