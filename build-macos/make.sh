#!/bin/zsh
source ~/ow2/wine-aoe4/env.sh
cd ~/ow2/wine-aoe4/build
make -j$(sysctl -n hw.ncpu)
echo "MAKE_EXIT=$?"
