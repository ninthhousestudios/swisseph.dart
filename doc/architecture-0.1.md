# Architecture

## Overview

`swisseph.dart` provides Dart FFI bindings to the Swiss Ephemeris C library. It compiles the C source at build time using Dart 3.11+ native asset hooks and exposes an instance-based Dart API through a single `SwissEph` class.

```
┌─────────────────────────────────────────────────┐
│  Dart application code                          │
│    import 'package:swisseph/swisseph.dart';     │
│    final swe = SwissEph.find();                 │
│    swe.calcUt(jd, seSun, seflgMoseph);          │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│  SwissEph  (lib/src/swiss_eph.dart)             │
│  Public API: 15 methods                         │
│  Owns DynamicLibrary + SweBindings              │
│  Allocates/frees native memory per call         │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│  SweBindings  (lib/src/bindings.dart)           │
│  16 late final FFI function pointers            │
│  lookupFunction<NativeType, DartType>()         │
└──────────────────┬──────────────────────────────┘
                   │  dart:ffi
┌──────────────────▼──────────────────────────────┐
│  libswisseph.so / .dylib / .dll                 │
│  Compiled from Swiss Ephemeris C source         │
│  9 C files, ~30k lines                          │
└─────────────────────────────────────────────────┘
```

## Build system

### Native asset build hook

`hook/build.dart` is a Dart 3.11+ native asset build hook. When `dart pub get` runs, the Dart toolchain detects the `hook.build.enabled: true` entry in `pubspec.yaml` and executes the hook.

The hook uses `package:native_toolchain_c` to:
1. Locate the C source — checks in order: `SWISSEPH_SRC` env var, vendored `csrc/` inside the package, sibling `../swisseph/` directory
2. Compile 9 C files with `CBuilder.library` at `-O2`
3. Output `libswisseph.so` (or `.dylib`/`.dll`) into `.dart_tool/`

The C source is vendored in `csrc/` so consumers don't need to clone it separately. Override with `SWISSEPH_SRC` or a sibling `../swisseph/` directory for local dev with newer C source.

**C source files compiled:**
- `sweph.c` — main calculation engine
- `swephlib.c` — math utilities (precession, nutation, etc.)
- `swecl.c` — eclipses
- `swehouse.c` — house systems
- `swehel.c` — heliacal events
- `swejpl.c` — JPL ephemeris reader
- `swemmoon.c` — Moshier Moon
- `swemplan.c` — Moshier planets
- `swedate.c` — Julian Day conversion

**Why build hook deps are in `dependencies`:** Build hooks execute during `dart pub get`, not during `dart test`. Packages in `dev_dependencies` aren't available to build hooks, so `hooks`, `code_assets`, and `native_toolchain_c` must be regular dependencies.

### Library discovery

`SwissEph.find()` calls `findLibrary()`, which recursively searches `.dart_tool/` for files named `libswisseph.so`, `libswisseph.dylib`, or `swisseph.dll`. For explicit paths, use `SwissEph('/path/to/libswisseph.so')`.

## FFI binding layer

### SweBindings (lib/src/bindings.dart)

Package-private class that wraps a `DynamicLibrary`. Each C function is bound as a `late final` field using `lookupFunction<NativeType, DartType>()`.

Lazy binding means the symbol lookup only happens on first access, not at construction. This avoids paying for symbols you don't use.

Example binding:

```dart
late final swe_calc_ut = _lib.lookupFunction<
    ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Int32,
        ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Char>),
    int Function(double, int, int, ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Char>)>('swe_calc_ut');
```

The native signature uses `ffi.Int32`, `ffi.Double`, etc. The Dart signature uses `int`, `double`, and `ffi.Pointer<T>`. The `lookupFunction` template does compile-time checking that these are compatible.

### Bound functions (16)

| C function | Category | Notes |
|------------|----------|-------|
| `swe_julday` | Date/time | Calendar date → Julian Day |
| `swe_revjul` | Date/time | Julian Day → calendar date |
| `swe_set_ephe_path` | Config | Path to .se1 data files |
| `swe_set_sid_mode` | Config | Select ayanamsa for sidereal mode |
| `swe_set_topo` | Config | Geographic position for topocentric |
| `swe_close` | Config | Free C-side resources |
| `swe_version` | Config | Library version string |
| `swe_calc_ut` | Calculation | Planetary positions (UT input) |
| `swe_houses` | Houses | House cusps for time/location |
| `swe_get_ayanamsa_ut` | Ayanamsa | Simple ayanamsa value |
| `swe_get_ayanamsa_ex_ut` | Ayanamsa | Ayanamsa with ephemeris flag |
| `swe_get_ayanamsa_name` | Ayanamsa | Name of ayanamsa mode |
| `swe_get_planet_name` | Names | Name of celestial body |
| `swe_house_name` | Names | Name of house system |
| `swe_rise_trans` | Rise/set | Rise, set, meridian transit |
| `swe_degnorm` | Utilities | Normalize degrees to 0-360 |

## Public API

### SwissEph class (lib/src/swiss_eph.dart)

The only public class. Each instance owns its own `DynamicLibrary` and `SweBindings`.

**Construction:**
- `SwissEph(String path)` — open a specific `.so`/`.dylib`/`.dll`
- `SwissEph.find()` — auto-locate in `.dart_tool/`

**Memory management pattern:**

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

`calloc` allocates zero-initialized native memory. The `try/finally` guarantees it's freed even on exceptions. No `Arena` or `using()` — the explicit pattern is simpler for single-allocation methods.

**Error handling:**

C functions that return negative values on error populate a `char[256]` error buffer. The Dart wrapper reads this and throws `SweException(message, returnFlag)`.

### Return types (lib/src/types.dart)

All immutable, with `const` constructors:

- **`CalcResult`** — 6 doubles (lon, lat, dist + speeds) + `returnFlag`. `swe_calc_ut` writes into a `double[6]` output array; the wrapper reads all 6 into named fields.

- **`HouseResult`** — `cusps` (13-element `List<double>`, index 0 unused to match C convention), `ascmc` (10-element `List<double>`), convenience getters `ascendant`, `mc`, `armc`, `vertex`. The C function writes into `double[37]` (cusps, up to 36 for Gauquelin) and `double[10]` (ascmc) output arrays.

- **`DateResult`** — year, month, day (int) + hour (double). `swe_revjul` writes into 4 separate output pointers.

- **`AyanamsaResult`** — ayanamsa (double) + `returnFlag`.

- **`RiseTransResult`** — transitTime (double) + `returnFlag`.

- **`SweException`** — message (String) + returnFlag (int). Implements `Exception`.

### Constants (lib/src/constants.dart)

~200 integer constants translated from `swephexp.h` and `sweodef.h`. Uses top-level `const int` rather than enums for direct compatibility with the C API's integer flags (which are combined with bitwise OR).

**Naming convention:** Dart lowerCamelCase derived from the C macro name:
- `SE_SUN` → `seSun`
- `SEFLG_SPEED` → `seflgSpeed`
- `SE_SIDM_LAHIRI` → `seSidmLahiri`
- `SE_HSYS_CAMPANUS` is not a C name — house systems are ASCII codes, so we define `hsysCampanus = 0x43` ('C')

## Isolate safety

### The problem

The Swiss Ephemeris C library stores state in global variables (selected ayanamsa, ephemeris path, topocentric position, etc.). On Linux, `dlopen` deduplicates by device+inode — if two isolates call `DynamicLibrary.open('/same/path')`, they get the **same** underlying handle and share C globals.

### The solution

Copy the `.so` file to a unique temporary path per isolate. Different inodes = different `dlopen` handles = independent C state.

```dart
// In each isolate:
final tmpPath = '/tmp/swisseph_${isolateId}.so';
File(originalPath).copySync(tmpPath);
final swe = SwissEph(tmpPath);
```

### The await-point hazard

Even with unique `.so` copies, Dart's cooperative scheduling means another microtask could run at any `await` point within the same isolate. If that microtask changes C config (e.g., `setSidMode`), your calculation after the `await` uses the wrong state.

Mitigation: re-set all configuration (`setSidMode`, `setEphePath`, `setTopo`) immediately before each calculation batch. Do not assume state set before an `await` persists after it.

### Test coverage

`test/isolate_test.dart` proves both behaviors:
1. **Unique paths**: Lahiri and Raman ayanamsas in parallel isolates produce different sidereal positions (>0.5° apart)
2. **Shared path**: Documents the contamination risk — same path may produce identical results despite different config

## Ephemeris modes

The Swiss Ephemeris supports three calculation backends:

| Mode | Flag | Files needed | Accuracy |
|------|------|-------------|----------|
| Moshier | `seflgMoseph` | None | ~1 arcsecond |
| Swiss Ephemeris | `seflgSwieph` | `.se1` files via `setEphePath()` | Sub-arcsecond |
| JPL | `seflgJpleph` | JPL ephemeris files | Highest |

All tests use Moshier mode so they run without external data files.

## Test architecture

### Unit tests

5 test files, 26 test cases:

| File | Tests | What it covers |
|------|-------|---------------|
| `date_test.dart` | 10 | julday, revjul, version, planet/house names, degnorm |
| `calc_test.dart` | 5 | calcUt (Sun, Moon, classical planets, error case), riseTrans |
| `houses_test.dart` | 4 | Campanus cusps, Whole Sign spacing, array lengths |
| `ayanamsa_test.dart` | 4 | Lahiri value, name, sidereal formula, ExUt consistency |
| `isolate_test.dart` | 2 | Unique paths isolation, shared path contamination |

Reference values use Moshier mode at J2000.0 (2000-01-01 00:00 UT, JD 2451544.5) or J2000 noon (JD 2451545.0). Values verified against direct C API calls, not `swetest` (which has a coordinate-swapping bug in its `-house` flag).

### Cross-validation against libaditya

`test/libaditya-validation/` contains a 545-value cross-validation suite that compares swisseph.dart's FFI bindings against [pyswisseph](https://gitlab.com/ninthhouse/libaditya) (the Python bindings to the same Swiss Ephemeris C library).

A Python script (`generate_reference.py`) calls pyswisseph to compute reference values and writes them to `reference_data.json`. A Dart test (`cross_validation_test.dart`) loads the JSON and compares every value against swisseph.dart.

| Category | Count | Coverage |
|----------|------:|----------|
| Planet positions (Moshier) | 91 | 13 bodies × 7 dates, all 6 output fields |
| House cusps | 154 | 11 systems × 7 locations × 2 dates |
| Ayanamsa values | 98 | 14 ayanamsas × 7 dates |
| Sidereal positions | 56 | Sun+Moon × 14 ayanamsas × 2 dates |
| Rise/set times | 32 | Sun+Moon rise+set × 4 locations × 2 dates |
| Other (degnorm, names, topo, equatorial, julday) | 114 | Full coverage of remaining API |

Most values match to 1e-8 (same C library, different FFI marshalling). Star-based ayanamsas (True Citra, etc.) and rise/set times use 1e-4 tolerance due to ephemeris engine differences.

## Android / NDK linking

### The problem

On desktop Linux, glibc implicitly links `libm` — math functions like `sin`, `cos`, `atan2`, `pow`, etc. are available without explicitly passing `-lm`. Android's Bionic libc does **not** do this. Without an explicit `-lm`, all math symbols are unresolved at runtime, causing `dlopen` to fail with "cannot locate symbol".

A second, subtler issue: clang at `-O2` recognizes adjacent `sin(x); cos(x)` call pairs and merges them into a single `sincos(x, &s, &c)` call. This is a valid optimization on glibc (which exports `sincos`), but on Bionic `sincos` is only available as a versioned symbol (`sincos@LIBC`) through `libm`. Without linking `libm`, the unversioned `sincos` reference fails to resolve.

### Failed approaches

1. **`-fno-builtin-sincos` compiler flag** — did not prevent clang from emitting `sincos` calls in practice.

2. **`compat.c` shim** providing `sincos()` via `sin()` + `cos()` — the compiler optimized the `sin()`/`cos()` calls inside the shim back into `sincos()`, creating infinite recursion. Stack overflow on Android: 512 frames, all `sincos` calling itself.

### The fix

Link `libm` explicitly via the `libraries` parameter in `CBuilder`:

```dart
final cBuilder = CBuilder.library(
  name: 'swisseph',
  // ...
  libraries: ['m'],
);
```

This produces `-lm` in the linker invocation. All math symbols (including `sincos`) get versioned (`@LIBC`) and resolve correctly from Bionic's `libm.so` at runtime. No shim files needed.

### Flutter-specific notes

`SwissEph.find()` searches `.dart_tool/` for the compiled library, which works on desktop but not on Android (no filesystem access to build artifacts at runtime). On Android, the native assets system bundles `libswisseph.so` into the APK's `lib/<abi>/` directory. Load it by name:

```dart
if (Platform.isAndroid) {
  return SwissEph('libswisseph.so');  // system linker finds it in the APK
}
return SwissEph.find();  // desktop: search .dart_tool/
```

Ephemeris `.se1` data files must be bundled as Flutter assets and extracted to the app's support directory at runtime, since Swiss Ephemeris reads them via filesystem paths (not asset bundles).

## Adding new Swiss Ephemeris functions

1. **Binding**: Add a `late final` field in `SweBindings` (`lib/src/bindings.dart`) with the function's native and Dart type signatures
2. **Result type**: If the function returns structured data, add a class in `lib/src/types.dart`
3. **Public method**: Add a method in `SwissEph` (`lib/src/swiss_eph.dart`) that allocates native memory, calls the binding, reads the result, and frees memory in a `finally` block
4. **Constants**: Add any new constants to `lib/src/constants.dart`
5. **Test**: Write a test with known reference values (use Moshier mode for no-file-dependency tests)

## Dependencies

| Package | Purpose | Why in `dependencies` |
|---------|---------|----------------------|
| `ffi` | `calloc`, `Utf8` helpers | Runtime FFI support |
| `logging` | Build hook logging | Used by build hook |
| `hooks` | Build hook framework | Build-time execution |
| `code_assets` | Native asset declaration | Build-time execution |
| `native_toolchain_c` | C compiler invocation | Build-time execution |
| `test` (dev) | Test framework | Test-time only |
