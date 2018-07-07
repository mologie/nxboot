#!/bin/bash
set -e
SRCS="flexec_main.m FLCmdTool.m FLExec.m FLUSBDevice.m FLUSBDeviceEnumerator.m NSData+FLHexEncoding.m"
CFLAGS="-std=gnu11 -fobjc-arc -fobjc-weak -fmodules -Wall -O2"
FRMWKS="-framework CoreFoundation -framework Foundation -framework IOKit"

xcrun -sdk iphoneos clang $SRCS $CFLAGS -arch arm64 -o flexec_arm64
jtool --sign --inplace --ent flexec.entitlements flexec_arm64

clang $SRCS $CFLAGS -arch x86_64 -o flexec_x86_64

lipo -create -output flexec flexec_arm64 flexec_x86_64
