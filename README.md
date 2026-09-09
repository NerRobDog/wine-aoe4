# wine-aoe4 — Wine for Age of Empires IV on Apple Silicon (Rosetta 2)

Patched Wine source used to build the `Engine/` of the AoE IV Apple Silicon
pack, so the pack does **not** depend on the GameToMac.app binary Engine.

Wine's own README is kept verbatim as [`README-wine.md`](README-wine.md).

## What this is

| Layer | Origin |
|---|---|
| Wine 11.0 | [Wine project](https://www.winehq.org), LGPL 2.1 |
| CrossOver 26.3 patches | [CodeWeavers](https://www.codeweavers.com) public CrossOver Wine source, LGPL 2.1 |
| AoE IV / Rosetta patch (`dlls/ntdll/unix/aoe_*`, `loader.c`, `signal_x86_64.c`, …) | **Marc Ibrahim**, [GameToMac](https://github.com) 0.1.5 Alpha (build 36). Softfault / cached-context software-exception path and generated-code cache so that the Arxan-protected game runs under Rosetta 2. HDE64 disassembler (`aoe_hde*`) under its own BSD-style notice. |
| Our changes | `ntdll: relocate near Jcc rel32 in the AoE code cache; dump refused fragments` — see `git log` |

Commit 1 of this repository is the byte-identical content of
`wine-source.tar.gz` (sha256 `7be5819017b34f09670293f2be7ed9f4476734b8f42dab121a8b74e6619c92a8`)
that ships inside GameToMac 0.1.5 Alpha at `Contents/Resources/Sources/`,
together with its `BUILD.md`, `RUNTIME-BUILD.md`, `VERSION.json` and
`Licenses/` copied to [`doc/gametomac/`](doc/gametomac/).

## License

LGPL 2.1 — see [`COPYING.LIB`](COPYING.LIB) and [`LICENSE`](LICENSE).
The complete corresponding source of every binary we distribute is this
repository at the commit stamped in the pack's `MANIFEST.md` / `HASHES.txt`.
Third-party notices bundled by GameToMac are in `doc/gametomac/Licenses/`.

## Building (macOS, x86_64 under Rosetta)

Follow [`doc/gametomac/RUNTIME-BUILD.md`](doc/gametomac/RUNTIME-BUILD.md)
(section "Wine and helper"). The exact scripts used for our build are in
[`build-macos/`](build-macos/):

- `env.sh` — toolchain: Xcode clang (`clang -arch x86_64`), LLVM-MinGW
  `20260826-ucrt` for the PE side, Homebrew-x86_64 freetype / gnutls / bison
  from `/usr/local/opt`. **Paths are machine-specific** — edit them for your
  checkout.
- `configure.sh` — out-of-tree configure with the flags from RUNTIME-BUILD.md:
  `--host=x86_64-apple-darwin --build=x86_64-apple-darwin --enable-archs=i386,x86_64
  --with-mingw=llvm-mingw --disable-tests --without-x --without-gstreamer --without-vulkan`.
- `make.sh` — `make -j$(sysctl -n hw.ncpu)`; then `make install` into the prefix.

Rough steps:

```sh
git clone <this repo> wine-aoe4/src/wine
mkdir -p wine-aoe4/build && cp wine-aoe4/src/wine/build-macos/*.sh wine-aoe4/
# edit wine-aoe4/env.sh for your toolchain paths
zsh wine-aoe4/configure.sh && zsh wine-aoe4/make.sh
( source wine-aoe4/env.sh && make -C wine-aoe4/build install )
```

The resulting `prefix/{bin,lib,share}` minus development files
(`include/`, `share/man`, `bin/{widl,winebuild,winegcc,…}`) is the pack's
`Engine/`. `builtin d3d11/d3d12/dxgi` are replaced by DXMT in the pack.

Runtime dependencies (`libfreetype.6.dylib`, `libgnutls.30.dylib` and their
deps) are `dlopen`'ed by soname; the pack ships them in `deps/Frameworks`
and the launcher sets `DYLD_LIBRARY_PATH` accordingly.

## Not upstream

Nothing here is submitted upstream (WineHQ, CodeWeavers or GameToMac).
No public git remote is configured on purpose.
