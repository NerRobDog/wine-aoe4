# GameToMac 2.1

Requires Xcode, an Apple Silicon Mac and the official Sparkle 2.9.6 distribution. Unpack Sparkle into a `sparkle` directory next to this source directory. Distribution SHA-256: `52bf9e88cdd972fc0c81501377a880e90d47031bd8ca5462488f843e2609e192` for `Sparkle-2.9.6.tar.xz`.

Compile the app:

```sh
xcrun swiftc -target arm64-apple-macos26.0 -F ../sparkle -framework Sparkle \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  Catalog.swift Core.swift UpdateSafety.swift Updates.swift main.swift -o GameLibrary
```

Embed Sparkle.framework in Contents/Frameworks. Preserve the original engine, helper binaries, licenses, game profiles, and art. The app bundle identifier remains `com.marcibrahim.gamelibrary`; do not rename its Application Support paths. Configure the SUFeedURL, SUPublicEDKey, SUEnableAutomaticChecks, SUVerifyUpdateBeforeExtraction and SURequireSignedFeed keys as described in UPDATES.md. Keep SUAutomaticallyUpdate, SUAllowsAutomaticUpdates and SUEnableSystemProfiling false.

Use `sign_release.py` with the Developer ID identity on an isolated staging app. This signs nested Sparkle helpers and creates the engine manifest before signing the main app. It does not expose or export signing keys. Then archive, notarize and package; see UPDATES.md.

Run Tests.swift and UpdateTests.swift as separate test executables, compiling each with Catalog.swift, Core.swift and UpdateSafety.swift. UpdateTests requires native process visibility. A complete release also requires an actual Sparkle replacement/relaunch check and real runtime fixtures.

RUNTIME-BUILD.md covers the unchanged custom Wine engine and sidecar sources. Third-party source and licenses remain bundled. New games must be added through validated games.json profiles; profiles using optimization `none` do not receive AoE-specific flags.
