# Build environment for GameToMac-patched Wine (CX 26.3 / Wine 11.0), x86_64 under Rosetta
MINGW=/Users/nik/ow2/dxmt/toolchains/llvm-mingw-20260826-ucrt-macos-universal
export PATH=/usr/local/opt/bison/bin:/usr/bin:/bin:/usr/sbin:/sbin:$MINGW/bin:/usr/local/bin
export CC='clang -arch x86_64' CXX='clang++ -arch x86_64'
export CFLAGS=-O2 CXXFLAGS=-O2
export PKG_CONFIG=/usr/local/bin/pkg-config
export PKG_CONFIG_LIBDIR=/usr/local/opt/freetype/lib/pkgconfig:/usr/local/opt/gnutls/lib/pkgconfig
export FREETYPE_CFLAGS="-I/usr/local/opt/freetype/include/freetype2"
export FREETYPE_LIBS="-L/usr/local/opt/freetype/lib -lfreetype"
export GNUTLS_CFLAGS="-I/usr/local/opt/gnutls/include"
export GNUTLS_LIBS="-L/usr/local/opt/gnutls/lib -lgnutls"
# PE side: no debug info (author strips it anyway; saves disk)
export x86_64_CFLAGS=-O2 i386_CFLAGS=-O2 CROSSDEBUG=none
