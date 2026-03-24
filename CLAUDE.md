# swisseph.dart

Dart FFI bindings to the Swiss Ephemeris C library. Requires Dart 3.11+.

## Build

The [Swiss Ephemeris C source](https://github.com/aloistr/swisseph) is vendored in `csrc/`. The native asset build hook (`hook/build.dart`) compiles it automatically — `dart pub get` triggers the build. Override with `SWISSEPH_SRC` env var or a sibling `../swisseph/` directory for local dev with newer C source.

The build hook packages (`hooks`, `code_assets`, `native_toolchain_c`) are in `dependencies`, not `dev_dependencies` — build hooks run at build time, not test time.

## Structure

```
csrc/                      # vendored Swiss Ephemeris C source (Astrodienst AG)
ephe/                      # bundled .se1 ephemeris data files (~5400 BC – 5400 AD)
lib/swisseph.dart          # barrel export
lib/src/swiss_eph.dart     # SwissEph class — ~88 public methods
lib/src/bindings.dart      # SweBindings — 75 raw dart:ffi lookups (package-private)
lib/src/constants.dart     # ~250 integer constants from swephexp.h
lib/src/types.dart         # 30+ result types (all immutable, const constructors)
hook/build.dart            # native asset build hook (CBuilder)
doc/architecture-0.2.md    # detailed architecture document
```

## API surface

`SwissEph` is the only public class. It wraps a `DynamicLibrary` and exposes ~88 methods across these categories:

- **Date/time** (14): `julday`, `revjul`, `utcToJd`, `jdToUtc`, `jdetToUtc`, `utcTimeZone`, `dayOfWeek`, `deltat`, `deltatEx`, `timeEqu`, `sidTime`, `sidTime0`, `lmtToLat`, `latToLmt`
- **Config** (13): `setEphePath`, `setSidMode`, `setTopo`, `setJplFile`, `setInterpolateNut`, `setLapseRate`, `setDeltaTUserdef`, `setTidAcc`, `getTidAcc`, `getLibraryPath`, `getCurrentFileData`, `close`, `version`
- **Positions** (8): `calcUt`, `calc`, `nodApsUt`, `nodAps`, `getOrbitalElements`, `orbitMaxMinTrueDistance`, `phenoUt`, `pheno`
- **Fixed stars** (3): `fixstar2Ut`, `fixstar2`, `fixstar2Mag`
- **Houses** (7): `houses`, `housesEx`, `housesEx2`, `housesArmc`, `housesArmcEx2`, `housePos`, `gauquelinSector`
- **Ayanamsa** (5): `getAyanamsaUt`, `getAyanamsa`, `getAyanamsaExUt`, `getAyanamsaEx`, `getAyanamsaName`
- **Eclipses** (10): `solEclipseWhenLoc`, `solEclipseWhenGlob`, `solEclipseHow`, `solEclipseWhere`, `lunEclipseWhen`, `lunEclipseWhenLoc`, `lunEclipseHow`, `lunOccultWhenLoc`, `lunOccultWhenGlob`, `lunOccultWhere`
- **Crossings** (8): `solCrossUt`, `solCross`, `moonCrossUt`, `moonCross`, `moonCrossNodeUt`, `moonCrossNode`, `helioCrossUt`, `helioCross`
- **Rise/set** (2): `riseTrans`, `riseTransTrueHor`
- **Heliacal** (3): `heliacalUt`, `heliacalPhenoUt`, `visLimitMag`
- **Coordinates** (5): `azAlt`, `azAltRev`, `cotrans`, `refrac`, `refracExtended`
- **Names** (2): `getPlanetName`, `houseName`
- **Utilities** (7): `degnorm`, `radNorm`, `degMidp`, `radMidp`, `difDegn`, `difDeg2n`, `splitDeg`

All native memory uses `calloc` + `try/finally free`. Errors throw `SweException`.

## Error patterns

Three C error patterns exist — see `doc/architecture-0.2.md` for details:
1. **Negative return + error buffer** — most functions (`calcUt`, `housesEx2`, etc.)
2. **JD sentinel** — crossing functions return `jdStart - 1` on error; check `result < jdStart`
3. **Integer return + output pointer** — heliocentric crossings; check `ret < 0`

## Constants

Integer constants, not enums. Prefixes: `se` (bodies), `seflg` (calc flags), `hsys` (house systems), `seSidm` (ayanamsa modes), `seCalc` (rise/set), `seEcl` (eclipses), `seNodbit` (nodes), `seHelflag` (heliacal), `seSidbit` (sidereal bits), `seSplitDeg` (degree splitting). See `lib/src/constants.dart`.

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
4. Add constants to `lib/src/constants.dart` if needed
5. Write test
