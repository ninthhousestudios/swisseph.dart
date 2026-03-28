## 0.4.3

- Fix Windows symbol exports: define `MAKE_DLL` during compilation so that
  `swephexp.h` decorates functions with `__declspec(dllexport)`. Without this,
  the built DLL has no exported symbols and `DynamicLibrary.lookup()` fails
  at runtime.

## 0.4.2

- Fix Windows build: skip `-lm` linker flag on Windows where math functions
  are part of the C runtime (ucrt). The `m.lib` file does not exist on
  Windows, causing `LNK1181` fatal link errors during native asset compilation.

## 0.4.1

- Rebuild WASM assets with correct file ownership for pub.dev publishing.

## 0.4.0

Cross-platform FFI architecture for native + web support.

### New
- `SwissEph.load()` — async factory constructor, works on both native and web
- WASM build infrastructure (`wasm/`) — Emscripten Docker build for web targets
- Pre-built `assets/swisseph.{js,wasm}` — 88 exported functions, 512 KB

### Changed
- All FFI types routed through conditional import barrel (`ffi_types.dart`)
- Library loading extracted to conditional barrel (`ffi_loader.dart`)
- `swiss_eph.dart` no longer imports `dart:io` — fully platform-agnostic
- `Char` → `Uint8` throughout all 88 bindings (web compatibility)
- All methods migrated from `calloc`/`free`/`try`/`finally` to Arena-scoped `using()`
- Custom UTF-8 string extensions (`utf8_compat.dart`) replacing `package:ffi` Utf8
- Added `wasm_ffi` dependency for web platform support

### Migration
- `SwissEph(path)` and `SwissEph.find()` still work on native (no changes needed)
- For cross-platform code, use `final swe = await SwissEph.load();`

## 0.3.0

**Breaking:** All constants renamed to consistent camelCase.

- Flag prefixes now properly capitalize sub-words: `seflgSwieph` → `seFlgSwiEph`, `seflgSpeed` → `seFlgSpeed`, etc.
- Node/apsides: `seNodbit*` → `seNodBit*`
- Heliacal flags: `seHelflag*` → `seHelFlag*`
- Sidereal bits: `seSidbit*` → `seSidBit*`
- Eclipse visibility: `seEclPartbegVisible` → `seEclPartBegVisible`, etc.
- Rise/set: `seCalcMtransit` → `seCalcMTransit`, `seBitGeoctrNoEclLat` → `seBitGeoCtrNoEclLat`
- Stress tests excluded from default `dart test` run (use `dart test -t stress`)

## 0.2.0

Major API expansion — 15 methods to ~88 methods, covering nearly the full
Swiss Ephemeris C API surface.

### New methods

**Planetary calculations:**
- `calc` (ET variant of `calcUt`)
- `nodApsUt`, `nodAps` — planetary nodes and apsides
- `getOrbitalElements` — osculating orbital elements
- `orbitMaxMinTrueDistance` — orbital distance extremes
- `phenoUt`, `pheno` — phase angle, elongation, magnitude

**Fixed stars:**
- `fixstar2Ut`, `fixstar2` — fixed star positions
- `fixstar2Mag` — visual magnitude lookup

**Houses (expanded):**
- `housesEx` — house cusps with extra flags
- `housesEx2` — house cusps with speeds
- `housesArmc` — houses from ARMC (no date needed)
- `housesArmcEx2` — houses from ARMC with speeds
- `housePos` — house position of a body
- `gauquelinSector` — Gauquelin sector position

**Eclipses:**
- `solEclipseWhenLoc`, `solEclipseWhenGlob` — find solar eclipses
- `solEclipseHow` — solar eclipse attributes at a location
- `solEclipseWhere` — geographic location of greatest eclipse
- `lunEclipseWhen`, `lunEclipseWhenLoc` — find lunar eclipses
- `lunEclipseHow` — lunar eclipse attributes
- `lunOccultWhenLoc`, `lunOccultWhenGlob` — planetary occultations
- `lunOccultWhere` — geographic location of greatest occultation

**Crossings:**
- `solCrossUt`, `solCross` — Sun crossing a longitude
- `moonCrossUt`, `moonCross` — Moon crossing a longitude
- `moonCrossNodeUt`, `moonCrossNode` — Moon crossing its own node
- `helioCrossUt`, `helioCross` — heliocentric longitude crossing

**Date/time (expanded):**
- `utcToJd`, `jdToUtc`, `jdetToUtc` — UTC/JD conversions
- `utcTimeZone` — UTC to local time zone
- `dayOfWeek` — day of week for a Julian Day
- `deltat`, `deltatEx` — Delta T (ET minus UT)
- `timeEqu` — equation of time
- `sidTime`, `sidTime0` — sidereal time
- `lmtToLat`, `latToLmt` — local mean/apparent time conversion

**Coordinate transforms:**
- `azAlt` — ecliptic/equatorial to horizon
- `azAltRev` — horizon to ecliptic/equatorial
- `cotrans` — ecliptic/equatorial coordinate transform
- `refrac`, `refracExtended` — atmospheric refraction
- `splitDeg` — decimal degrees to d/m/s
- `radNorm`, `degMidp`, `radMidp`, `difDegn`, `difDeg2n` — degree/radian math

**Rise/set (expanded):**
- `riseTransTrueHor` — rise/set with true horizon

**Heliacal:**
- `heliacalUt` — heliacal rising/setting
- `heliacalPhenoUt` — heliacal phenomenon data
- `visLimitMag` — limiting visual magnitude

**Configuration (expanded):**
- `setJplFile` — set JPL ephemeris file
- `getLibraryPath` — path to loaded shared library
- `getCurrentFileData` — loaded data file info
- `setInterpolateNut` — nutation interpolation toggle
- `setLapseRate` — atmospheric lapse rate
- `setDeltaTUserdef` — override Delta T
- `setTidAcc`, `getTidAcc` — tidal acceleration
- `getAyanamsa`, `getAyanamsaEx` — ET ayanamsa variants

### Bug fixes (from external code review)

- **Gauquelin cusp truncation** — house methods now return all 37 cusps
  for Gauquelin sectors (`hsys='G'`), not just 13. Affected: `houses`,
  `housesEx`, `housesEx2`, `housesArmc`, `housesArmcEx2`.
- **Crossing function error detection** — `solCross*`, `moonCross*`, and
  `moonCrossNode*` now check `result < jdStart` (matching the C error
  sentinel) instead of `result < 0`, which was a no-op for modern dates.
- **Missing error throws** — `houses()`, `housesEx()`, `housesArmc()` now
  throw `SweException` on failure (consistent with `housesEx2`).
- **FixstarResult returnFlag** — `fixstar2Ut` and `fixstar2` now populate
  the `returnFlag` field.
- **gauquelinSector starName** — added optional `starName` parameter for
  fixed-star sector calculations.
- **Constant and doc fixes** — added `hsysGauquelin` constant, clarified
  `seEcl2hor`/`seHor2ecl` docs (direction comes from function, not flag),
  documented `SplitDegResult.sign` zodiacal behavior, documented
  `RiseTransResult` circumpolar behavior (returnFlag -2).

### New types

`HouseResultEx`, `FixstarResult`, `MoonNodeCrossResult`, `JulianDayPair`,
`DateTimeResult`, `FileDataResult`, `NodeApsResult`,
`OrbitalElementsResult`, `OrbitDistanceResult`, `PhenoResult`,
`SolarEclipseLocalResult`, `SolarEclipseGlobalResult`,
`SolarEclipseAttrResult`, `EclipseWhereResult`,
`LunarEclipseGlobalResult`, `LunarEclipseLocalResult`,
`LunarEclipseAttrResult`, `AzAltResult`, `AzAltRevResult`,
`CoTransResult`, `RefracResult`, `HeliacalResult`,
`HeliacalPhenoResult`, `VisLimitResult`, `AtmoConditions`,
`ObserverConditions`.

### Other

- FFI bindings expanded from 16 to 75.
- Constants expanded with eclipse flags, node/apsides flags, heliacal
  event types, sidereal mode bits, split degree flags, and refraction flags.

## 0.1.2

- Fix Android/NDK linking: link `libm` explicitly via `libraries: ['m']`
  in the build hook. Desktop glibc links libm implicitly; Android's Bionic
  does not, causing `dlopen` failures for math symbols (`sin`, `cos`,
  `sincos`, etc.).
- Document ephemeris file discovery for package consumers: use
  `Isolate.resolvePackageUri` to locate the bundled `ephe/` directory
  at runtime.

## 0.1.1

- Bundle Swiss Ephemeris data files in `ephe/` — sub-arcsecond precision
  out of the box with no extra downloads.
- Included: planets, Moon, main asteroids (Ceres, Pallas, Juno, Vesta,
  Chiron, Pholus), fixed stars, and Hygiea.
- Coverage: ~5400 BC – 5400 AD (~10,800 years).

## 0.1.0

- Initial release.
- 15 methods: `calcUt`, `houses`, `julday`, `revjul`, `riseTrans`,
  `getAyanamsaUt`, `getAyanamsaExUt`, `getAyanamsaName`, `setSidMode`,
  `setEphePath`, `setTopo`, `getPlanetName`, `houseName`, `degnorm`,
  `close`, `version`.
- All 47 standard ayanamsa modes.
- 11 house systems.
- Moshier, Swiss Ephemeris, and JPL ephemeris support.
- Tropical, sidereal, heliocentric, barycentric, and equatorial
  coordinates.
- Native asset build hook — C source compiles automatically on
  `dart pub get`.
- Isolate-safe via unique `.so` copies per isolate.
- 26 unit tests + 545-value cross-validation against pyswisseph.
