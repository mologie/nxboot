#!/bin/zsh
# This script is called by build.sh
set -euo pipefail

projdir=$(realpath "$(dirname "$0")")
dpkgdir=DerivedData/dpkg
pkgid=com.mologie.NXBoot

for arch in iphoneos-arm iphoneos-arm64; do
  if [ "$arch" = "iphoneos-arm" ]; then
    distdir=/
  else
    distdir=/var/jb
  fi

  archdir="$dpkgdir/$arch"
  ctrldir="$archdir/$pkgid/DEBIAN"
  datadir="$archdir/${pkgid}${distdir}"
  rm -rf "$archdir"

  # control file
  mkdir -p "$ctrldir"
  sed "s/Version: PLACEHOLDER/Version: $version-$buildno/;s/Architecture: iphoneos-arm/Architecture: ${arch}/" DEBIAN/control > $ctrldir/control
  cp DEBIAN/postinst "$ctrldir/"

  # application
  mkdir -p "$datadir/Applications"
  rsync -r "$releasedir/NXBoot.app" "$datadir/Applications/"
  test "$arch" = "iphoneos-arm" || cp "$releasedir/NXBoot.arm64" "$datadir/Applications/NXBoot.app/NXBoot"

  # cmdline tool
  mkdir -p "$datadir/usr/bin"
  if [ "$arch" = "iphoneos-arm" ]; then
    cp dist/iphoneos/nxboot "$datadir/usr/bin/nxboot"
  else
    lipo dist/iphoneos/nxboot -thin arm64 -output "$datadir/usr/bin/nxboot"
  fi

  deb=${pkgid}_${version}_${buildno}_${arch}.deb
  pushd "$archdir"
  chown -R 0:0 .
  chown -R 0:80 "${pkgid}${distdir}/Applications"
  dpkg-deb -Zgzip -b "$pkgid" "$projdir/dist/iphoneos/$deb"
  chown $uid:$gid "$projdir/dist/iphoneos/$deb"
  chown -R $uid:$gid .
  popd
done
