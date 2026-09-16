#!/bin/bash
# Check that an engine tree is the one a game pack may ship as Engine/.
#
#   build-macos/test-package-engine.sh <engine-dir>
#
# Run it on what package-engine.sh produced. Run it on a raw `make install`
# prefix and it has to fail: that is the tree which cost a night on 2026-09-16.
#
# Each check is a fact a pack relies on and that nothing else would announce:
#
#   - No x86_64 d3d11/d3d12/dxgi.dll under lib/wine. Wine looks in its own
#     lib/wine before WINEDLLPATH, so with them present a DXMT pack loads Wine's
#     builtin d3d12, the game finds "no adapter which supports Direct3D 12" and
#     exits with code 2 about 30 seconds in - a crash that looks like the game's.
#   - The i386 copies still there. 32-bit programs (Steam's own helpers among
#     them) get nothing from a pack's x86_64 DXMT; removing those would break
#     them instead of fixing anything.
#   - No *.a import libraries, no include/, no compiler tools (winegcc, widl,
#     ...) and no man pages: build inputs and documentation, not runtime. The
#     v0.3 engine shipped none of them and ran.
#   - .build-id equal to this source tree's HEAD, so the pack credits the commit
#     whose scripts and sources describe this engine.
#   - .profile-user = satoru. A pack renames C:\users\crossover to exactly this;
#     the wrong or a missing name either strands a player's profile or silently
#     skips the migration.
set -u

HERE="$(cd "$(dirname "$0")/.." && pwd -P)"
ENGINE="${1:-}"
[ -n "$ENGINE" ] && [ -d "$ENGINE" ] || { echo "usage: build-macos/test-package-engine.sh <engine-dir>" >&2; exit 2; }

fail=0
ok()  { echo "  ok    $*"; }
bad() { echo "  FAIL  $*"; fail=1; }

for d in d3d11 d3d12 dxgi; do
    f="$ENGINE/lib/wine/x86_64-windows/$d.dll"
    [ -e "$f" ] && bad "x86_64-windows/$d.dll is present: it shadows DXMT's from WINEDLLPATH" \
                || ok "x86_64-windows/$d.dll absent"
    f="$ENGINE/lib/wine/i386-windows/$d.dll"
    [ -f "$f" ] && ok "i386-windows/$d.dll kept" \
                || bad "i386-windows/$d.dll is missing: 32-bit programs lose their builtin"
done

[ -f "$ENGINE/bin/wine" ] && [ -f "$ENGINE/lib/wine/x86_64-unix/ntdll.so" ] \
    && ok "bin/wine and x86_64-unix/ntdll.so present" \
    || bad "not a runnable engine (bin/wine or x86_64-unix/ntdll.so missing)"

n="$(find "$ENGINE" -name '*.a' | wc -l | tr -d ' ')"
[ "$n" = 0 ] && ok "no *.a import libraries" || bad "$n *.a import libraries left"
[ -e "$ENGINE/include" ] && bad "include/ present" || ok "no include/"
tools=""
for t in function_grep.pl widl winebuild winecpp winedump wineg++ winegcc winemaker wmc wrc; do
    [ -e "$ENGINE/bin/$t" ] && tools="$tools $t"
done
[ -z "$tools" ] && ok "no build tools in bin/" || bad "build tools in bin/:$tools"
[ -e "$ENGINE/share/man" ] && bad "share/man present" || ok "no share/man"

head_id="$(cd "$HERE" && git rev-parse HEAD 2>/dev/null)"
build_id="$(tr -d '[:space:]' < "$ENGINE/.build-id" 2>/dev/null)"
[ -n "$build_id" ] && [ "$build_id" = "$head_id" ] \
    && ok ".build-id = HEAD ($head_id)" \
    || bad ".build-id is '${build_id:-<none>}', source HEAD is $head_id"

profile="$(tr -d '[:space:]' < "$ENGINE/.profile-user" 2>/dev/null)"
[ "$profile" = satoru ] && ok ".profile-user = satoru" \
    || bad ".profile-user is '${profile:-<none>}', expected satoru"

[ "$fail" = 0 ] && echo "PASS: $ENGINE is shippable" || echo "FAIL: $ENGINE is not what a pack may ship"
exit "$fail"
