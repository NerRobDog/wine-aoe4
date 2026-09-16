#!/bin/bash
# Turn an installed engine (`make install` prefix) into the Engine/ a game pack ships.
#
#   build-macos/package-engine.sh <installed-prefix> <out-engine-dir>
#
# <out-engine-dir> must not exist or be empty; the installed prefix is only read.
# The result is stamped (stamp-engine.sh) and should pass test-package-engine.sh.
#
# Why this is a script and not a habit. The v0.3 engine had three dlls removed
# from lib/wine/x86_64-windows - d3d11, d3d12, dxgi - by a hand step nobody wrote
# down. Engine v2 was installed straight from `make install`, kept them, and AoE IV
# on it exited with code 2 after 30 seconds: "No adapter found which supports
# Direct3D 12". Wine searches its own lib/wine before WINEDLLPATH, so its builtin
# d3d12 is found first and the pack's DXMT in WINEDLLPATH is never loaded. Nothing
# in the log says "shadowed"; it looks like the game failing on the GPU.
#
# What is left out, and why each is safe:
#
#   x86_64-windows/{d3d11,d3d12,dxgi}.dll
#       see above. Only the 64-bit ones: packs ship DXMT for x86_64 only, and the
#       i386 builtins are what 32-bit programs (Steam's helpers) still get.
#   include/, lib/**/*.a
#       headers and import libraries are read by a compiler. A pack copies an
#       engine, it never builds against one. (make-pack.sh in the AoE IV pack
#       deletes *.a too; doing it here keeps both answers the same.)
#   bin/{widl,winebuild,winegcc,wineg++,winecpp,winedump,winemaker,wmc,wrc,
#        function_grep.pl}, share/man
#       the compiler toolchain and its manual pages. Named one by one rather
#       than "everything but wine and wineserver": a runtime binary added to bin/
#       by a later Wine has to ship unless someone decides otherwise.
#
# Other builtins DXMT also provides (d3d10core) are not touched: v0.3 kept them
# and ran, and this script reproduces v0.3's tree, not a new policy.
set -u

die() { echo "package-engine: $*" >&2; exit 1; }

HERE="$(cd "$(dirname "$0")/.." && pwd -P)"
SRC="${1:-}"
OUT="${2:-}"

[ -n "$SRC" ] && [ -n "$OUT" ] || die "usage: build-macos/package-engine.sh <installed-prefix> <out-engine-dir>"
[ -x "$SRC/bin/wine" ] && [ -d "$SRC/lib/wine" ] || die "$SRC does not look like an installed engine (no bin/wine or lib/wine)"

# An existing tree would be merged into, and a file this script removes from the
# copy would survive from whatever was there before. Start empty or not at all.
if [ -e "$OUT" ]; then
    [ -d "$OUT" ] && [ -z "$(ls -A "$OUT")" ] || die "$OUT exists and is not empty; nothing was written"
fi
src_real="$(cd "$SRC" && pwd -P)"
mkdir -p "$OUT" || die "cannot create $OUT"
out_real="$(cd "$OUT" && pwd -P)"
# Packaging in place would strip the installed prefix a test stand runs from.
[ "$src_real" != "$out_real" ] || die "refusing to package $SRC into itself"

# cp -a keeps symlinks as symlinks (winecpp, wineg++ are links to winegcc) and
# keeps the modes the loader needs.
for part in bin lib share; do
    [ -d "$SRC/$part" ] || continue
    cp -a "$SRC/$part" "$OUT/$part" || die "copying $SRC/$part failed"
done

for d in d3d11 d3d12 dxgi; do
    rm -f "$OUT/lib/wine/x86_64-windows/$d.dll"
done
find "$OUT" -name '*.a' -delete
for t in function_grep.pl widl winebuild winecpp winedump wineg++ winegcc winemaker wmc wrc; do
    rm -f "$OUT/bin/$t"
done
rm -rf "$OUT/share/man"

# The stamp reads the source tree this script lives in; the engine has to have
# been built from it, which stamp-engine.sh checks against advapi32.
bash "$HERE/build-macos/stamp-engine.sh" "$OUT" || die "stamp-engine.sh refused $OUT (above)"
echo "packaged $SRC -> $OUT"
