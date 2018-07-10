#!/bin/sh
set -e
./build.sh
ssh root@singetail rm -f /jb/bin/nxboot
scp nxboot root@singetail:/jb/bin/nxboot
echo iOS nxbuild binary has been updated
