#!/bin/zsh
set -e
source ~/ow2/wine-aoe4/env.sh
cd ~/ow2/wine-aoe4/build
exec ~/ow2/wine-aoe4/src/wine/configure \
  --host=x86_64-apple-darwin --build=x86_64-apple-darwin \
  --enable-archs=i386,x86_64 --with-mingw=llvm-mingw \
  --disable-tests --without-x --without-gstreamer --without-vulkan \
  --prefix=$HOME/ow2/wine-aoe4/prefix
