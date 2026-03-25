# Architecture — swisseph.dart 0.2

## Overview

`swisseph.dart` provides Dart FFI bindings to the Swiss Ephemeris C library.
It compiles the C source at build time using Dart 3.11+ native asset hooks
and exposes an instance-based Dart API through a single `SwissEph` class.

Version 0.2 expands from 15 to ~88 public methods and from 16 to 75 FFI
bindings, covering nearly the full Swiss Ephemeris API surface.

```
┌──────────────────────────────────────────────────────┐
│  Dart application code                               │
│    import 'package:swisseph/swisseph.dart';          │
│    final swe = SwissEph.find();                      │
│    swe.calcUt(jd, seSun, seFlgMosEph);               │
└───────────────────┬──────────────────────────────────┘
                    │
┌───────────────────▼──────────────────────────────────┐
│  SwissEph  (lib/src/swiss_eph.dart)                  │
│  Public API: ~88 methods                             │
│  Owns DynamicLibrary + SweBindings                   │
│  Allocates/frees native memory per call              │
└───────────────────┬──────────────────────────────────┘
                    │
┌───────────────────▼──────────────────────────────────┐
│  SweBindings  (lib/src/bindings.dart)                │
│  75 late final FFI function pointers                 │
│  lookupFunction<NativeType, DartType>()              │
└───────────────────┬──────────────────────────────────┘
                    │  dart:ffi
┌───────────────────▼──────────────────────────────────┐
│  libswisseph.so / .dylib / .dll                      │
│  Compiled from Swiss Ephemeris C source              │
│  9 C files, ~30k lines                               │
└──────────────────────────────────────────────────────┘
```

## File structure

```
swisseph.dart/
├── csrc/                          # Vendored Swiss Ephemeris C source
├── ephe/                          # Bundled .se1 ephemeris data files
├── hook/
│   └── build.dart                 # Native asset build hook (CBuilder)
├── lib/
│   ├── swisseph.dart              # Barrel export
│   └── src/
│       ├── bindings.dart          # SweBindings — 75 raw FFI lookups
│       ├── swiss_eph.dart         # SwissEph — ~88 public methods
│       ├── types.dart             # Result types (all immutable)
│       └── constants.dart         # ~250 integer constants from swephexp.h
├── test/
│   ├── date_test.dart             # julday, revjul, version, names, degnorm
│   ├── calc_test.dart             # calcUt, riseTrans, error cases
│   ├── houses_test.dart           # Campanus, Whole Sign, array lengths
│   ├── ayanamsa_test.dart         # Lahiri value, name, ExUt consistency
│   ├── isolate_test.dart          # Unique paths, shared path contamination
│   └── libaditya-validation/      # 545-value cross-validation vs pyswisseph
├── example/
│   └── example.dart               # Usage demo
├── doc/
│   ├── architecture-0.1.md        # Previous architecture doc
│   └── architecture-0.2.md        # This file
└── pubspec.yaml
```

## Build system

### Native asset build hook

`hook/build.dart` is a Dart 3.11+ native asset build hook. When `dart pub get`
runs, the Dart toolchain detects `hook.build.enabled: true` in `pubspec.yaml`
and executes the hook.

The hook uses `package:native_toolchain_c` to:
1. Locate the C source — checks in order: `SWISSEPH_SRC` env var, vendored
   `csrc/` inside the package, sibling `../swisseph/` directory
2. Compile 9 C files with `CBuilder.library` at `-O2`
3. Link `libm` explicitly (required for Android/Bionic)
4. Output `libswisseph.so` (or `.dylib`/`.dll`) into `.dart_tool/`

**C source files compiled:**

| File | Purpose |
|------|---------|
| `sweph.c` | Main calculation engine |
| `swephlib.c` | Math utilities (precession, nutation, etc.) |
| `swecl.c` | Eclipses, crossings, occultations |
| `swehouse.c` | House systems |
| `swehel.c` | Heliacal events |
| `swejpl.c` | JPL ephemeris reader |
| `swemmoon.c` | Moshier Moon |
| `swemplan.c` | Moshier planets |
| `swedate.c` | Julian Day conversion |

**Why build hook deps are in `dependencies`:** Build hooks execute during
`dart pub get`, not during `dart test`. Packages in `dev_dependencies`
aren't available to build hooks, so `hooks`, `code_assets`, and
`native_toolchain_c` must be regular dependencies.

### Library discovery

`SwissEph.find()` calls `findLibrary()`, which recursively searches
`.dart_tool/` for files named `libswisseph.so`, `libswisseph.dylib`, or
`swisseph.dll`. For explicit paths, use `SwissEph('/path/to/libswisseph.so')`.

**Limitation:** `findLibrary()` uses `.dart_tool/` relative to CWD, which
breaks if CWD differs from the package root. For production use, pass an
explicit path or use the native asset loading mechanism directly.

### Android / NDK

Android's Bionic libc does not implicitly link `libm`. The build hook
passes `libraries: ['m']` to `CBuilder` to explicitly link it. Without
this, all math symbols (`sin`, `cos`, `sincos`, etc.) are unresolved at
runtime.

On Android, the native assets system bundles `libswisseph.so` into the
APK's `lib/<abi>/` directory. Load by name:

```dart
if (Platform.isAndroid) {
  return SwissEph('libswisseph.so');  // system linker finds it in the APK
}
return SwissEph.find();  // desktop: search .dart_tool/
```

## FFI binding layer

### SweBindings (lib/src/bindings.dart)

Package-private class wrapping a `DynamicLibrary`. Each C function is
bound as a `late final` field using `lookupFunction<NativeType, DartType>()`.

Lazy binding means the symbol lookup only happens on first access, not at
construction. This avoids paying for symbols you don't use.

Example binding:

```dart
late final swe_calc_ut = _lib.lookupFunction<
    ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Int32,
        ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Char>),
    int Function(double, int, int, ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Char>)>('swe_calc_ut');
```

### Bound functions (75)

| Category | Count | Functions |
|----------|------:|-----------|
| Date/time | 8 | `swe_julday`, `swe_revjul`, `swe_utc_to_jd`, `swe_jdut1_to_utc`, `swe_jdet_to_utc`, `swe_utc_time_zone`, `swe_date_conversion`, `swe_day_of_week` |
| Configuration | 10 | `swe_set_ephe_path`, `swe_set_sid_mode`, `swe_set_topo`, `swe_close`, `swe_version`, `swe_set_jpl_file`, `swe_get_library_path`, `swe_get_current_file_data`, `swe_set_interpolate_nut`, `swe_set_lapse_rate` |
| Planetary calc | 2 | `swe_calc_ut`, `swe_calc` |
| Houses | 7 | `swe_houses`, `swe_houses_ex`, `swe_houses_ex2`, `swe_houses_armc`, `swe_houses_armc_ex2`, `swe_house_pos`, `swe_gauquelin_sector` |
| Ayanamsa | 5 | `swe_get_ayanamsa_ut`, `swe_get_ayanamsa`, `swe_get_ayanamsa_ex_ut`, `swe_get_ayanamsa_ex`, `swe_get_ayanamsa_name` |
| Names | 2 | `swe_get_planet_name`, `swe_house_name` |
| Fixed stars | 3 | `swe_fixstar2_ut`, `swe_fixstar2`, `swe_fixstar2_mag` |
| Crossings | 8 | `swe_solcross_ut`, `swe_solcross`, `swe_mooncross_ut`, `swe_mooncross`, `swe_mooncross_node_ut`, `swe_mooncross_node`, `swe_helio_cross_ut`, `swe_helio_cross` |
| Eclipses | 10 | `swe_sol_eclipse_when_loc`, `swe_sol_eclipse_when_glob`, `swe_sol_eclipse_how`, `swe_sol_eclipse_where`, `swe_lun_eclipse_when`, `swe_lun_eclipse_when_loc`, `swe_lun_eclipse_how`, `swe_lun_occult_when_loc`, `swe_lun_occult_when_glob`, `swe_lun_occult_where` |
| Rise/set | 2 | `swe_rise_trans`, `swe_rise_trans_true_hor` |
| Delta T / time | 9 | `swe_deltat`, `swe_deltat_ex`, `swe_time_equ`, `swe_sidtime`, `swe_sidtime0`, `swe_lmt_to_lat`, `swe_lat_to_lmt`, `swe_set_delta_t_userdef`, `swe_set_tid_acc` (+`swe_get_tid_acc`) |
| Coordinate/util | 6 | `swe_azalt`, `swe_azalt_rev`, `swe_cotrans`, `swe_refrac`, `swe_refrac_extended`, `swe_degnorm` |
| Degree math | 6 | `swe_split_deg`, `swe_radnorm`, `swe_deg_midp`, `swe_rad_midp`, `swe_difdegn`, `swe_difdeg2n` |
| Nodes/apsides | 2 | `swe_nod_aps_ut`, `swe_nod_aps` |
| Orbital | 2 | `swe_get_orbital_elements`, `swe_orbit_max_min_true_distance` |
| Phenomena | 2 | `swe_pheno_ut`, `swe_pheno` |
| Heliacal | 3 | `swe_heliacal_ut`, `swe_heliacal_pheno_ut`, `swe_vis_limit_mag` |

## Public API

### SwissEph class (lib/src/swiss_eph.dart)

The only public class. Each instance owns its own `DynamicLibrary` and
`SweBindings`.

**Construction:**
- `SwissEph(String path)` — open a specific `.so`/`.dylib`/`.dll`
- `SwissEph.find()` — auto-locate in `.dart_tool/`

**Method categories (~88 total):**

| Category | Count | Key methods |
|----------|------:|-------------|
| Date/time | 14 | `julday`, `revjul`, `utcToJd`, `jdToUtc`, `jdetToUtc`, `utcTimeZone`, `dayOfWeek`, `deltat`, `deltatEx`, `timeEqu`, `sidTime`, `sidTime0`, `lmtToLat`, `latToLmt` |
| Configuration | 13 | `setEphePath`, `setSidMode`, `setTopo`, `setJplFile`, `setInterpolateNut`, `setLapseRate`, `setDeltaTUserdef`, `setTidAcc`, `getTidAcc`, `getLibraryPath`, `getCurrentFileData`, `close`, `version` |
| Planetary | 8 | `calcUt`, `calc`, `nodApsUt`, `nodAps`, `getOrbitalElements`, `orbitMaxMinTrueDistance`, `phenoUt`, `pheno` |
| Fixed stars | 3 | `fixstar2Ut`, `fixstar2`, `fixstar2Mag` |
| Houses | 7 | `houses`, `housesEx`, `housesEx2`, `housesArmc`, `housesArmcEx2`, `housePos`, `gauquelinSector` |
| Ayanamsa | 5 | `getAyanamsaUt`, `getAyanamsa`, `getAyanamsaExUt`, `getAyanamsaEx`, `getAyanamsaName` |
| Eclipses | 10 | `solEclipseWhenLoc`, `solEclipseWhenGlob`, `solEclipseHow`, `solEclipseWhere`, `lunEclipseWhen`, `lunEclipseWhenLoc`, `lunEclipseHow`, `lunOccultWhenLoc`, `lunOccultWhenGlob`, `lunOccultWhere` |
| Crossings | 8 | `solCrossUt`, `solCross`, `moonCrossUt`, `moonCross`, `moonCrossNodeUt`, `moonCrossNode`, `helioCrossUt`, `helioCross` |
| Rise/set | 2 | `riseTrans`, `riseTransTrueHor` |
| Heliacal | 3 | `heliacalUt`, `heliacalPhenoUt`, `visLimitMag` |
| Coordinates | 5 | `azAlt`, `azAltRev`, `cotrans`, `refrac`, `refracExtended` |
| Names | 2 | `getPlanetName`, `houseName` |
| Degree/radian | 7 | `degnorm`, `radNorm`, `degMidp`, `radMidp`, `difDegn`, `difDeg2n`, `splitDeg` |

### Memory management pattern

Every method that needs native memory follows the same pattern:

```dart
ReturnType method(args) {
  final ptr = pkg_ffi.calloc<ffi.SomeType>(count);
  try {
    _bind.some_c_function(ptr);
    return ReturnType(/* read from ptr */);
  } finally {
    pkg_ffi.calloc.free(ptr);
  }
}
```

`calloc` allocates zero-initialized native memory. The `try/finally`
guarantees it's freed even on exceptions. No `Arena` or `using()` — the
explicit pattern is simpler and more predictable.

Methods that need multiple allocations stack them in a single `try/finally`:

```dart
ReturnType method(args) {
  final pResult = pkg_ffi.calloc<ffi.Double>(20);
  final pAttrs = pkg_ffi.calloc<ffi.Double>(20);
  final serr = pkg_ffi.calloc<ffi.Char>(256);
  try {
    _bind.some_function(pResult, pAttrs, serr);
    // read results...
  } finally {
    pkg_ffi.calloc.free(serr);
    pkg_ffi.calloc.free(pAttrs);
    pkg_ffi.calloc.free(pResult);
  }
}
```

### Error handling

Three error patterns exist in the C API, and the Dart wrappers handle
each differently:

**Pattern 1: Negative return + error buffer.** Most functions (`swe_calc_ut`,
`swe_houses_ex2`, etc.) return a negative integer on error and fill a
`char[256]` buffer with the error message. The wrapper throws
`SweException(message, returnFlag)`.

```dart
if (ret < 0) {
  throw SweException(serr.cast<Utf8>().toDartString(), ret);
}
```

**Pattern 2: JD sentinel.** Crossing functions (`swe_solcross_ut`, etc.)
return `jd_start - 1` on error — a JD value one day before the search
start. The wrapper checks `result < jdStart`:

```dart
if (result < jdUt) {
  throw SweException(serr.cast<Utf8>().toDartString(), -1);
}
```

This is NOT the same as checking for negative values — Julian Day numbers
for modern dates are ~2.4 million, so `result < 0` would never fire.

**Pattern 3: Integer return code via output pointer.** Heliocentric
crossing functions (`swe_helio_cross`, `swe_helio_cross_ut`) return an
integer error code and write the JD result into a separate output pointer.
The wrapper checks `ret < 0`:

```dart
if (ret < 0) {
  throw SweException(serr.cast<Utf8>().toDartString(), ret);
}
return pResult.value;
```

### Variable-size output arrays

Some C functions write different amounts of data depending on a parameter.
The Dart wrapper must branch accordingly.

**House cusps:** Normally 13 elements (index 0 unused + 12 cusps).
For Gauquelin sectors (`hsys = 0x47 / 'G'`), the C function writes 37
elements (index 0 unused + 36 sectors). The buffer is always allocated
at 37, but the read-back count must match:

```dart
final cuspCount = hsys == 0x47 ? 37 : 13;
final cusps = List<double>.generate(cuspCount, (i) => pCusps[i]);
```

### Return types (lib/src/types.dart)

All result types are immutable with `const` constructors. Major categories:

**Core results:**

| Type | Source method(s) | Key fields |
|------|-----------------|------------|
| `CalcResult` | `calcUt`, `calc` | `longitude`, `latitude`, `distance` + speeds, `returnFlag` |
| `HouseResult` | `houses`, `housesEx`, `housesArmc` | `cusps`, `ascmc` (Lists), getters: `ascendant`, `mc`, `armc`, `vertex` |
| `HouseResultEx` | `housesEx2`, `housesArmcEx2` | Above + `cuspSpeeds`, `ascmcSpeeds` |
| `DateResult` | `revjul` | `year`, `month`, `day`, `hour` |
| `DateTimeResult` | `jdToUtc`, `jdetToUtc`, `utcTimeZone` | `year`, `month`, `day`, `hour`, `min`, `sec` |
| `AyanamsaResult` | `getAyanamsaExUt`, `getAyanamsaEx` | `ayanamsa`, `returnFlag` |
| `RiseTransResult` | `riseTrans`, `riseTransTrueHor` | `transitTime`, `returnFlag` |

**Fixed star / crossing results:**

| Type | Source method(s) | Key fields |
|------|-----------------|------------|
| `FixstarResult` | `fixstar2Ut`, `fixstar2` | `starName`, position + speeds, `returnFlag` |
| `MoonNodeCrossResult` | `moonCrossNodeUt`, `moonCrossNode` | `jdUt`, `longitude`, `latitude` |
| `JulianDayPair` | `utcToJd` | `et`, `ut1` |

**Eclipse results:**

| Type | Source method(s) | Key fields |
|------|-----------------|------------|
| `SolarEclipseLocalResult` | `solEclipseWhenLoc`, `lunOccultWhenLoc` | Timing contacts + magnitude/obscuration attrs |
| `SolarEclipseGlobalResult` | `solEclipseWhenGlob`, `lunOccultWhenGlob` | Global timing (begin, end, totality, center line) |
| `SolarEclipseAttrResult` | `solEclipseHow` | Magnitude, diameter ratio, obscuration, Saros |
| `EclipseWhereResult` | `solEclipseWhere`, `lunOccultWhere` | `geolon`, `geolat` + attributes |
| `LunarEclipseGlobalResult` | `lunEclipseWhen` | Partial/total/penumbral timing |
| `LunarEclipseLocalResult` | `lunEclipseWhenLoc` | Above + moonrise/set + magnitudes |
| `LunarEclipseAttrResult` | `lunEclipseHow` | Umbral/penumbral magnitudes, Saros |

**Coordinate / utility results:**

| Type | Source method(s) | Key fields |
|------|-----------------|------------|
| `AzAltResult` | `azAlt` | `azimuth`, `trueAltitude`, `apparentAltitude` |
| `AzAltRevResult` | `azAltRev` | `lon`, `lat` |
| `CoTransResult` | `cotrans` | `lon`, `lat`, `dist` |
| `RefracResult` | `refracExtended` | `trueAltitude`, `apparentAltitude`, `refraction`, `horizonDip` |
| `SplitDegResult` | `splitDeg` | `degrees`, `minutes`, `seconds`, `secondsFraction`, `sign` |

**Orbital / phenomena results:**

| Type | Source method(s) | Key fields |
|------|-----------------|------------|
| `NodeApsResult` | `nodApsUt`, `nodAps` | `ascending`, `descending`, `perihelion`, `aphelion` (each a `CalcResult`) |
| `OrbitalElementsResult` | `getOrbitalElements` | 17 orbital element fields |
| `OrbitDistanceResult` | `orbitMaxMinTrueDistance` | `maxDist`, `minDist`, `trueDist` |
| `PhenoResult` | `phenoUt`, `pheno` | `phaseAngle`, `phase`, `elongation`, `apparentDiameter`, `apparentMagnitude` |

**Heliacal results:**

| Type | Source method(s) | Key fields |
|------|-----------------|------------|
| `HeliacalResult` | `heliacalUt` | `startVisible`, `bestVisible`, `endVisible` |
| `HeliacalPhenoResult` | `heliacalPhenoUt` | Altitude, azimuth, arc data + `raw` list |
| `VisLimitResult` | `visLimitMag` | `limitMagnitude`, object/sun/moon positions |

**Parameter types:**

| Type | Used by | Fields |
|------|---------|--------|
| `AtmoConditions` | `heliacalUt`, `heliacalPhenoUt`, `visLimitMag` | `pressure`, `temperature`, `humidity`, `extinction` |
| `ObserverConditions` | Same heliacal methods | `age`, `snellenRatio`, `monoNoBino`, `telescopeDia`, `telescopeMag`, `eyeHeight` |

### Constants (lib/src/constants.dart)

~250 integer constants translated from `swephexp.h` and `sweodef.h`. Uses
top-level `const int` rather than enums for direct compatibility with the
C API's integer flags (combined with bitwise OR).

**Naming convention:** Dart lowerCamelCase derived from the C macro name:
- `SE_SUN` → `seSun`
- `SEFLG_SPEED` → `seFlgSpeed`
- `SE_SIDM_LAHIRI` → `seSidmLahiri`
- House systems are ASCII codes: `hsysCampanus = 0x43` (`'C'`)

**Constant groups:**

| Group | Prefix | Count | Examples |
|-------|--------|------:|---------|
| Body IDs | `se` | 23 | `seSun`, `seMoon`, `seChiron`, `seCupido` |
| Calc flags | `seFlg` | 20 | `seFlgSpeed`, `seFlgSidereal`, `seFlgJ2000` |
| House systems | `hsys` | 14 | `hsysPlacidus`, `hsysGauquelin` |
| Ayanamsa modes | `seSidm` | 48 | `seSidmLahiri`, `seSidmUser` |
| Rise/set | `seCalc` / `seBit` | 12 | `seCalcRise`, `seBitDiscCenter` |
| Eclipse types | `seEcl` | 16 | `seEclTotal`, `seEclPartial`, `seEclOneTry` |
| Node/apsides | `seNodBit` | 4 | `seNodBitMean`, `seNodBitOscu` |
| Heliacal | `seHeliacal` / `seHelFlag` / `seMorning` / `seEvening` | 8 | `seHeliacalRising`, `seHelFlagHighPrecision` |
| Sidereal bits | `seSidBit` | 6 | `seSidBitEclT0`, `seSidBitPrecOrig` |
| Split degree | `seSplitDeg` | 7 | `seSplitDegRoundSec`, `seSplitDegNakshatra` |
| Refraction | `seTrueToApp` / `seAppToTrue` | 2 | Direction flags for `refrac` |
| Az/alt | `seEcl2hor` / `seEqu2hor` | 4 | Coordinate system selection (not direction) |
| Calendar | `seGregCal` / `seJulCal` | 2 | Gregorian vs Julian calendar |

## Isolate safety

### The problem

The Swiss Ephemeris C library stores state in global variables (selected
ayanamsa, ephemeris path, topocentric position, etc.). On Linux, `dlopen`
deduplicates by device+inode — if two isolates call
`DynamicLibrary.open('/same/path')`, they get the **same** underlying
handle and share C globals.

### The solution

Copy the `.so` file to a unique temporary path per isolate. Different
inodes = different `dlopen` handles = independent C state.

```dart
final tmpPath = '/tmp/swisseph_${isolateId}.so';
File(originalPath).copySync(tmpPath);
final swe = SwissEph(tmpPath);
```

### The await-point hazard

Even with unique `.so` copies, Dart's cooperative scheduling means another
microtask could run at any `await` point within the same isolate. If that
microtask changes C config (e.g., `setSidMode`), your calculation after
the `await` uses the wrong state.

Mitigation: re-set all configuration (`setSidMode`, `setEphePath`,
`setTopo`) immediately before each calculation batch. Do not assume state
set before an `await` persists after it.

### Test coverage

`test/isolate_test.dart` proves both behaviors:
1. **Unique paths**: Lahiri and Raman ayanamsas in parallel isolates
   produce different sidereal positions (>0.5 degrees apart)
2. **Shared path**: Documents the contamination risk — same path may
   produce identical results despite different config

## Ephemeris data

### Bundled files

The `ephe/` directory contains Swiss Ephemeris data files covering
~5400 BC to ~5400 AD:

| File pattern | Contents |
|-------------|----------|
| `sepl_*.se1` / `seplm*.se1` | Main planets (Sun–Pluto, lunar nodes) |
| `semo_*.se1` / `semom*.se1` | Moon (high precision) |
| `seas_*.se1` / `seasm*.se1` | Main asteroids |
| `sefstars.txt` | ~1000 named fixed stars |
| `ast0/se00010s.se1` | Asteroid 10 (Hygiea) |

### Ephemeris engines

| Mode | Flag | Files needed | Accuracy |
|------|------|-------------|----------|
| Moshier | `seFlgMosEph` | None | ~1 arcsecond |
| Swiss Ephemeris | `seFlgSwiEph` | `.se1` files via `setEphePath()` | Sub-arcsecond |
| JPL | `seFlgJplEph` | JPL ephemeris files | Highest |

All tests use Moshier mode so they run without external data files.

## Test architecture

### Unit tests

5 test files, 26 test cases:

| File | Tests | Coverage |
|------|------:|---------|
| `date_test.dart` | 10 | julday, revjul, version, planet/house names, degnorm |
| `calc_test.dart` | 5 | calcUt (Sun, Moon, classical planets, error case), riseTrans |
| `houses_test.dart` | 4 | Campanus cusps, Whole Sign spacing, array lengths |
| `ayanamsa_test.dart` | 4 | Lahiri value, name, sidereal formula, ExUt consistency |
| `isolate_test.dart` | 2 | Unique paths isolation, shared path contamination |

Reference values use Moshier mode at J2000.0 (JD 2451544.5) or J2000 noon
(JD 2451545.0). Values verified against direct C API calls, not `swetest`
(which has a coordinate-swapping bug in its `-house` flag).

### Cross-validation against libaditya

`test/libaditya-validation/` contains a 545-value cross-validation suite
comparing swisseph.dart against [pyswisseph](https://gitlab.com/ninthhouse/libaditya).

| Category | Count | Coverage |
|----------|------:|----------|
| Planet positions (Moshier) | 91 | 13 bodies x 7 dates, all 6 output fields |
| House cusps | 154 | 11 systems x 7 locations x 2 dates |
| Ayanamsa values | 98 | 14 ayanamsas x 7 dates |
| Sidereal positions | 56 | Sun+Moon x 14 ayanamsas x 2 dates |
| Rise/set times | 32 | Sun+Moon rise+set x 4 locations x 2 dates |
| Other | 114 | degnorm, names, topo, equatorial, julday |

### Test gaps (known)

The 0.2 API expansion added ~73 new methods. Many are exercised only by
the cross-validation suite or not yet tested:

- Gauquelin sector house calculations (no test for `hsys='G'`)
- Crossing function error paths (no test for JD sentinel detection)
- `riseTrans` circumpolar behavior (returnFlag -2, transitTime 0.0)
- Eclipse/occultation methods (basic smoke tests only)
- Heliacal methods (no tests)
- Coordinate transforms (no dedicated tests)

## C API coverage

Of the ~82 exported functions in `swephexp.h`, 75 are bound. The remaining
unbound functions are:

- `swe_fixstar_ut` / `swe_fixstar` — deprecated in favor of `swe_fixstar2_*`
- `swe_houses_ex` (old signature) — superseded by `swe_houses_ex2`
- `swe_csnorm` / `swe_difcsn` / `swe_difdeg2n` / `swe_csroundsec` —
  centisecond utilities rarely needed in Dart
- `swe_date_conversion` — bound but no public wrapper (use `julday` instead)

## Dependencies

| Package | Purpose | Why in `dependencies` |
|---------|---------|----------------------|
| `ffi` | `calloc`, `Utf8` helpers | Runtime FFI support |
| `logging` | Build hook logging | Used by build hook |
| `hooks` | Build hook framework | Build-time execution |
| `code_assets` | Native asset declaration | Build-time execution |
| `native_toolchain_c` | C compiler invocation | Build-time execution |
| `test` (dev) | Test framework | Test-time only |

## Design decisions

### Why one class, not many?

The Swiss Ephemeris C API is a flat namespace of ~82 functions that share
global state. Splitting into multiple Dart classes (e.g., `EclipseCalculator`,
`HouseCalculator`) would add indirection without meaningful encapsulation —
the C state is still shared underneath. A single `SwissEph` class makes the
shared-state reality explicit.

### Why integer constants, not enums?

The C API uses integer flags combined with bitwise OR. Dart enums can't
participate in bitwise operations without boilerplate. Integer constants
map 1:1 to C values and combine naturally: `seFlgMosEph | seFlgSpeed | seFlgSidereal`.

### Why calloc + try/finally, not Arena?

The `Arena` pattern (`using((arena) { ... })`) adds a callback layer and
requires `package:ffi`'s `Arena` class. The explicit `calloc`/`free` in
`try/finally` is more visible, debuggable, and doesn't nest when multiple
allocations are needed. Every allocation site follows the same pattern,
making the codebase grep-able for memory management.

### Why late final bindings?

`late final` defers the `dlopen` symbol lookup until first use. For a
library with 75 bound functions, this means you only pay the lookup cost
for functions you actually call. Since most users need only a handful of
functions (positions, houses, ayanamsa), the majority of lookups never
happen.
