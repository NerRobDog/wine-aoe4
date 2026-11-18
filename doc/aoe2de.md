# Age of Empires II: Definitive Edition with the soft-fault path

AoE2 DE (`AoE2DE_s.exe`, Steam app 813780) has used the same anti-tamper scheme as AoE IV since its 2 June 2026 patch:
- invalid-in-long-mode opcodes as traps (observed: `0x16`, PUSH SS),
- handled by the game's own vectored exception handler,
- which then continues into generated code.

Under stock CrossOver this costs about 15,000 kernel traps per second in busy scenes. FPS collapses with the number of units that have health bars or are selected.

The engine needs **no code change** for AoE2: the generic `X87_COOP_EXE` path in `__wine_main` plus environment variables is enough.

## Environment

```sh
export WINELOADER=<engine>/bin/wine
export AOELAB_SIDECAR_PATH=<path>/x87sidecar     # NerRobDog/x87sidecar >= 4b6bad8
export X87_COOP_EXE=AoE2DE_s.exe
export AOELAB_SOFTFAULT_BRIDGE=1                 # maps the bridge at 0x180000000
export AOE_SOFTFAULT_TARGET1=0x180000000
export AOE_SOFTFAULT_TARGET=0x180000010
export X87_ALWAYS_NONE=1
# .text of AoE2DE_s.exe; read it from the PE header, it changes with game updates.
# 101.103.57257.0 (sha256 1e415af8b7fbbe6aeb4e1eebf888f43e9d9b8b9129df2bd010d0a7a60dc3ca16):
export AOE_SOFTFAULT_PC=0x140001000
export AOE_SOFTFAULT_END=0x143195ef2
```

Do **not** set `AOELAB_CODE_CACHE_GAME`. The code cache reads a RelicCardinal-specific pointer and is gated to that executable anyway.

## Results

Measured with an equivalent port of the same soft-fault code into the stock CrossOver 26.3.0 ntdll. It was **not** run on this engine build. Patch and scripts: https://github.com/kyrios/aoe2-mac-softfault

Setup: M2 Max, macOS 27.2.

| | Stock | Soft-fault |
|---|---|---|
| Test program, `0x16` trap with VEH skip | 53.5 µs/trap | 0.62 µs/trap |
| Game: SIGILL via kernel (DTrace) | about 15,000/s | 0 |
| Game: paused busy scene, 60 units selected | about 10–12 FPS | about 22 FPS |

**Remaining cost:** the handler still toggles about 30–50k code pages per second (RWX/RX), and the game threads still sit in Rosetta's runtime. Re-translation of the rewritten pages is the likely cause.
