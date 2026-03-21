# swisseph.dart

Dart FFI bindings to the Swiss Ephemeris C library. Requires Dart 3.11+.

## Build

The [Swiss Ephemeris C source](https://github.com/aloistr/swisseph) is vendored in `csrc/`. The native asset build hook (`hook/build.dart`) compiles it automatically — `dart pub get` triggers the build. Override with `SWISSEPH_SRC` env var or a sibling `../swisseph/` directory for local dev with newer C source.

The build hook packages (`hooks`, `code_assets`, `native_toolchain_c`) are in `dependencies`, not `dev_dependencies` — build hooks run at build time, not test time.

## Structure

```
csrc/                      # vendored Swiss Ephemeris C source (Astrodienst AG)
lib/swisseph.dart          # barrel export
lib/src/swiss_eph.dart     # SwissEph class — all public API
lib/src/bindings.dart      # SweBindings — raw dart:ffi lookups (package-private)
lib/src/constants.dart     # SE_* integer constants from swephexp.h
lib/src/types.dart         # CalcResult, HouseResult, DateResult, etc.
hook/build.dart            # native asset build hook (CBuilder)
```

## API surface

`SwissEph` is the only public class. It wraps a `DynamicLibrary` and exposes 15 methods:

- `julday`, `revjul` — date conversion
- `setEphePath`, `setSidMode`, `setTopo`, `close`, `version` — configuration
- `calcUt` — planetary positions (returns `CalcResult`)
- `houses` — house cusps (returns `HouseResult`)
- `getAyanamsaUt`, `getAyanamsaExUt`, `getAyanamsaName` — ayanamsa
- `getPlanetName`, `houseName` — name lookups
- `riseTrans` — rise/set/transit times
- `degnorm` — normalize degrees to 0-360

All native memory uses `calloc` + `try/finally free`. Errors throw `SweException`.

## Constants

Integer constants, not enums. Prefixes: `se` (bodies), `seflg` (calc flags), `hsys` (house systems), `seSidm` (ayanamsa modes), `seCalc` (rise/set). See `lib/src/constants.dart`.

## Isolate safety

`dlopen` deduplicates by device+inode. Same `.so` path = shared C globals across isolates. For true isolation, copy the `.so` to a unique temp path per isolate (see `test/isolate_test.dart`).

Global state drifts across `await` points — re-set config (`setSidMode`, `setEphePath`, `setTopo`) before each calculation batch.

## Tests

```
dart test
```

26 unit tests across 5 files: date_test, calc_test, houses_test, ayanamsa_test, isolate_test. All use Moshier ephemeris (no data files needed).

### Cross-validation against libaditya

`test/libaditya-validation/` contains 545 reference values generated from [pyswisseph](https://gitlab.com/ninthhouse/libaditya) and a Dart test that compares every value against swisseph.dart. Covers 13 bodies, 14 ayanamsas, 11 house systems, 7 locations, 7 dates. See `test/libaditya-validation/README.md`.

## Adding new functions

1. Add `late final` lookup in `lib/src/bindings.dart`
2. Add public method in `lib/src/swiss_eph.dart`
3. Add result type in `lib/src/types.dart` if needed
4. Write test
