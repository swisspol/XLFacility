#!/bin/sh -ex

# brew install clang-format

CLANG_FORMAT_VERSION=`clang-format -version | awk '{ print $3 }'`
if [[ "$CLANG_FORMAT_VERSION" != "4.0.0" ]]; then
  echo "Unsupported clang-format version"
  exit 1
fi

pushd "GCDNetworking"
clang-format -style=file -i *.h *.m
popd
pushd "Tests"
clang-format -style=file -i *.m
popd

pushd "CLT"
clang-format -style=file -i *.m
popd
pushd "iOS"
clang-format -style=file -i *.h *.m
popd

echo "OK"
