#!/bin/bash -ex

# Run GCDTelnetServer tests first
pushd "GCDTelnetServer"
./Run-Tests.sh
popd

OSX_SDK="macosx"
if [ -z "$TRAVIS" ]; then
  IOS_SDK="iphoneos"
else
  IOS_SDK="iphonesimulator"
fi

OSX_TARGET="XLFacility (Mac)"
IOS_TARGET="XLFacility (iOS)"
CONFIGURATION="Release"

BUILD_DIR="/tmp/XLFacility"
PRODUCT="$BUILD_DIR/$CONFIGURATION/XLFacility"

# Build for iOS for oldest deployment target
rm -rf "$BUILD_DIR"
xcodebuild -sdk "$IOS_SDK" -target "$IOS_TARGET" -configuration "$CONFIGURATION" build "SYMROOT=$BUILD_DIR" "IPHONEOS_DEPLOYMENT_TARGET=5.0"

# Build for iOS for default deployment target
rm -rf "$BUILD_DIR"
xcodebuild -sdk "$IOS_SDK" -target "$IOS_TARGET" -configuration "$CONFIGURATION" build "SYMROOT=$BUILD_DIR"

# Build for OS X for oldest deployment target
rm -rf "$BUILD_DIR"
xcodebuild -sdk "$OSX_SDK" -target "$OSX_TARGET" -configuration "$CONFIGURATION" build "SYMROOT=$BUILD_DIR" "MACOSX_DEPLOYMENT_TARGET=10.7"

# Build for OS X for default deployment target
rm -rf "$BUILD_DIR"
xcodebuild -sdk "$OSX_SDK" -target "$OSX_TARGET" -configuration "$CONFIGURATION" build "SYMROOT=$BUILD_DIR"

# Run tests
xcodebuild test -scheme "Tests"

# Done
echo "\nAll tests completed successfully!"
