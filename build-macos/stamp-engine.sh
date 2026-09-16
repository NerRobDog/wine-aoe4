#!/bin/bash
# Write the two facts a pack needs to know about an engine tree it is about to ship:
# which commit built it, and what it calls the Windows profile inside a prefix.
#
#   build-macos/stamp-engine.sh <engine-dir>
#
# <engine-dir> is an installed tree - the one a pack ships as Engine/ - with
# bin/, lib/ and share/ in it. Both facts are written at its root:
#
#   .build-id      the commit this source tree is at, which the pack credits in
#                  THIRD_PARTY and checks in tools/check-version.sh.
#   .profile-user  the constant profile name this engine answers GetUserName
#                  with. A pack renames an older prefix's profile to match, and
#                  does nothing at all when this file is absent.
#
# The second one is the dangerous one, which is why it is derived and checked
# rather than typed. A pack told the wrong name renames C:\users\<old> out from
# under an engine that still looks for it; the engine then finds no profile,
# builds an empty one beside the renamed original, and the player's settings,
# saves and screenshots stay in a directory nothing opens again. Nothing
# announces that. So the name comes from the source this engine was built from,
# and it is written only after the engine's own advapi32 has been seen to carry
# it. An engine still using CrossOver's name gets no file, and every pack
# shipping it then leaves prefixes alone - which is correct, not a gap.
set -u

die() { echo "stamp-engine: $*" >&2; exit 1; }

HERE="$(cd "$(dirname "$0")/.." && pwd -P)"
ENGINE="${1:-}"

[ -n "$ENGINE" ] || die "usage: build-macos/stamp-engine.sh <engine-dir>"
[ -d "$ENGINE" ] || die "$ENGINE is not a directory"
[ -d "$ENGINE/lib/wine" ] || die "$ENGINE does not look like an installed engine (no lib/wine)"

SRC="$HERE/dlls/advapi32/advapi.c"
[ -f "$SRC" ] || die "cannot find $SRC - run this from the Wine source tree that built the engine"

# Everything is decided before anything is written: a refusal has to leave the
# engine tree exactly as it found it, or "nothing was stamped" is a lie and the
# next build inherits half an answer.

build_id="$(cd "$HERE" && git rev-parse HEAD 2>/dev/null || true)"
[ -n "$build_id" ] || die "$HERE is not a git checkout; cannot record which commit built this engine"
if ! (cd "$HERE" && git diff --quiet && git diff --cached --quiet) 2>/dev/null; then
    echo "stamp-engine: WARNING - the source tree has uncommitted changes, so $build_id" >&2
    echo "              does not fully describe what was built." >&2
fi

# One line in one file decides the profile name, and it is the same line the
# engine compiles.
name="$(sed -n 's/^#define[[:space:]]*DEFAULT_USER_NAMEA[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' \
        "$SRC" | head -1)"

if [ -n "$name" ]; then
    case "$name" in
        *[!A-Za-z0-9._-]*|.|..) die "$SRC declares \"$name\", which is not a usable directory name" ;;
    esac

    # The source says one thing; the binary about to be shipped has to agree. A
    # tree rebuilt after an edit, or an Engine copied from an older build, would
    # otherwise be stamped with a name it does not answer to.
    found=0
    for dll in "$ENGINE"/lib/wine/*-windows/advapi32.dll; do
        [ -f "$dll" ] || continue
        found=1
        /usr/bin/strings -a "$dll" | /usr/bin/grep -qx "$name" \
            || die "$dll does not contain \"$name\": the engine in $ENGINE was not built from
this source tree. Rebuild or stage the matching engine; nothing was stamped."
    done
    [ "$found" = 1 ] || die "no advapi32.dll under $ENGINE/lib/wine/*-windows - cannot confirm the
profile name this engine answers with; nothing was stamped."
fi

printf '%s\n' "$build_id" > "$ENGINE/.build-id"
echo "  .build-id      $build_id"

if [ -z "$name" ]; then
    rm -f "$ENGINE/.profile-user"
    echo "  .profile-user  not written: this engine still uses CrossOver's constant name."
    echo "                 Packs shipping it will leave existing prefixes alone."
    exit 0
fi

printf '%s\n' "$name" > "$ENGINE/.profile-user"
echo "  .profile-user  $name (confirmed in the engine's own advapi32)"
