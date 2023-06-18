#!/bin/zsh
# This script is called by build.sh
set -euo pipefail

dpkgdir=DerivedData/dpkg
rm -rf $dpkgdir
mkdir -p $dpkgdir/com.mologie.NXBoot/{DEBIAN,Applications}
cat DEBIAN/control | sed "s/Version: PLACEHOLDER/Version: $version-$buildno/" > $dpkgdir/com.mologie.NXBoot/DEBIAN/control
cp DEBIAN/postinst $dpkgdir/com.mologie.NXBoot/DEBIAN/
rsync -a $releasedir/NXBoot.app $dpkgdir/com.mologie.NXBoot/Applications/
mkdir -p $dpkgdir/com.mologie.NXBoot/usr/bin
cp dist/iphoneos/nxboot $dpkgdir/com.mologie.NXBoot/usr/bin/nxboot

projdir=$(pwd)
cd $dpkgdir
chown -R 0:0 .
chown -R 0:80 com.mologie.NXBoot/Applications
dpkg-deb -Zgzip -b com.mologie.NXBoot "$projdir/dist/iphoneos/com.mologie.NXBoot-$version-$buildno.deb"
chown $uid:$gid "$projdir/dist/iphoneos/com.mologie.NXBoot-$version-$buildno.deb"
chown -R $uid:$gid .
