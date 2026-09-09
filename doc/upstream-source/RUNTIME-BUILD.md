# Source and build notes

The .app includes complete corresponding patched Wine source in `Contents/Resources/Sources/wine-source.tar.gz` and the modified MIT sidecar source in `sidecar-source.tar.gz`. HDE64's source and notices are in Wine's `dlls/ntdll/unix/aoe_hde*` files. Native launcher sources are included alongside these archives.

## Native launcher

Requires Apple's command-line developer tools only on the build machine:

```sh
xcrun swiftc -target arm64-apple-macos26.0 Core.swift main.swift -o AoEIVPortable
xcrun swiftc -target arm64-apple-macos26.0 GameBridge.swift -o GameBridge
```

Install these into the bundle's `Contents/MacOS` and `Contents/Helpers` respectively. The user-facing app has no Python or Homebrew dependency. `Runtime` derives resources from its bundle and state from the user's Application Support folder; `--data-root` is available for isolated CLI QA.

## Wine and helper

Wine's source base is CodeWeavers' public CrossOver 26.3 Wine source (Wine 11.0). Included source already contains the Steam CEF single-process change, aggregate diagnostics, the cached-context software-exception path, and generated-code cache. Key files include `dlls/ntdll/unix/loader.c`, `signal_x86_64.c`, `aoe_code_cache.h`, `aoe_relocate.h`, PE exception code and Unix-call plumbing. The game executable itself is not included or modified.

The original build used Xcode clang targeting x86_64, LLVM-MinGW `20260826-ucrt`, and these configure flags:

```
--host=x86_64-apple-darwin --build=x86_64-apple-darwin
--enable-archs=i386,x86_64 --with-mingw=llvm-mingw
--disable-tests --without-x --without-gstreamer --without-vulkan
--prefix=<build destination>
```

Use the pinned Sikarugir package's x86-64 dependency libraries, matching FreeType/GnuTLS headers, `CC='clang -arch x86_64'`, `CXX='clang++ -arch x86_64'`, and `CFLAGS=CXXFLAGS=-O2`. Set FreeType and GnuTLS include/library paths explicitly for your checkout, then run configure, make, and make install. Keep the generated PE ntdll and Unix ntdll paired. Strip debug-only PE sections with LLVM strip (`--strip-debug`), not executable content. Preserve exported entry points. The helper is built from the included CMake source; use the flat `x87sidecar` executable rather than its separately entitled variant.

`relocate_runtime.py` records the packaging transformations against the original source layout. Runtime packaging retains Wine bin/lib/share runtime files, records external dependency links for first setup, changes build-specific Mach-O RPATHs to relative paths, changes two bare dylib names to @rpath, and replaces the build username prefix in embedded build paths without changing string lengths or suffix relationships. It signs the resulting local binaries ad hoc. The helper's executable code is the previously tested helper build. The native GameBridge validates the installed executable SHA-256 before invoking it.

The first-run dependency manifest links the engine only to that portable instance's downloaded Frameworks directory. Both the template and Steam bootstrap installer are pinned by SHA-256. Steam's own updater remains responsible for its subsequent client updates.

## Validation

Run `--command check --data-root <empty test folder>` and `--command prepare --data-root <empty test folder>` from the built app's executable. `prepare` is a developer diagnostic that omits the GUI license prompt and Steam install; normal users use Set up Steam and review the license first. Do not point QA at an existing game prefix.

The package's validation report records fresh-prefix creation, retry behavior, relocated exception/cache fixtures, incorrect-game rejection, and a fresh Steam startup. No game account or installed game is included. A second Mac is still needed for M1 gameplay validation.

Ad-hoc signatures allow local integrity validation, but are not Developer ID signatures or Apple notarization. A public distribution should use an appropriate signing/notarization workflow; this package does not contain a developer credential or signing identity.
