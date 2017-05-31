#!/bin/sh -ex

# brew install clang-format

CLANG_FORMAT_VERSION=`clang-format -version | awk '{ print $3 }'`
if [[ "$CLANG_FORMAT_VERSION" != "5.0.0" ]]; then
  echo "Unsupported clang-format version"
  exit 1
fi

pushd "XLFacility/Core"
clang-format -style=file -i *.h *.m
popd
pushd "XLFacility/Extensions"
clang-format -style=file -i *.h *.m
popd
pushd "XLFacility/UserInterface"
clang-format -style=file -i *.h *.m
popd
pushd "Tests"
clang-format -style=file -i *.m
popd

pushd "CLT"
clang-format -style=file -i *.c *.m
popd
pushd "iOS"
clang-format -style=file -i *.h *.m
popd
pushd "Mac"
clang-format -style=file -i *.h *.m
popd
pushd "TCPServer"
clang-format -style=file -i *.m
popd

echo "OK"
