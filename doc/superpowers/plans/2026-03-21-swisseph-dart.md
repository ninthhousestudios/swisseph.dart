# swisseph.dart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build isolate-safe Dart FFI bindings to the Swiss Ephemeris C library, starting with the ~16 functions Arrow needs and designed to grow to all 82+.

**Architecture:** Instance-based `SwissEph` class wrapping a `DynamicLibrary`. Each instance has independent C global state (when loaded from a unique .so path). Raw bindings in a private `SweBindings` class; public API uses Arena-based memory management and returns Dart-idiomatic types. C source compiled via Dart 3.10+ native asset build hooks.

**Tech Stack:** Dart 3.11+, dart:ffi, package:native_toolchain_c (build hook), package:test

---

## Reference Material

- **C source (fork):** `/home/josh/nhs/soft/swisseph/` (swephexp.h is the public API header)
- **C API docs:** `/home/josh/nhs/soft/swisseph/claude/catalogue-public.md` (106 functions, all signatures)
- **Variable glossary:** `/home/josh/nhs/soft/swisseph/claude/variable-glossary.md`
- **sweph.dart reference:** `/home/josh/nhs/soft/sweph.dart/sweph.dart/lib/` (Arena patterns, type signatures)
- **Arrow architecture:** `/home/josh/nhs/soft/arjuna/arrow/claude/arch/` (how this fits into the stack)

### Reference Test Values (Swiss Ephemeris mode, .se1 files)

Generated with swetest v2.10.03 using `-edir./ephe`:

**Planets at 2000-01-01 00:00 TT (JD 2451544.5 TT), tropical:**
| Body    | Longitude     | Speed        |
|---------|---------------|--------------|
| Sun     | 279.8584613   | 1.0193830    |
| Moon    | 217.2843444   | 12.1032708   |
| Mercury | 271.1106588   | 1.5536312    |
| Venus   | 240.9605179   | 1.2084662    |
| Mars    | 327.5748966   | 0.7756576    |
| Jupiter | 25.2331011    | 0.0390670    |
| Saturn  | 40.4058797    | -0.0208594   |

**Lahiri ayanamsa at 2000-01-01 00:00 TT:** 23°51'11.5325 ≈ 23.8532035°

**Sidereal (Lahiri) positions at same time:**
| Body | Longitude     |
|------|---------------|
| Sun  | 256.0052579   |
| Moon | 193.4311409   |

**Campanus houses at 2000-01-01 12:00 UT, Washington DC (38.8977°N, 77.0365°W):**
| House | Cusp         |
|-------|--------------|
| 1     | 18.0703033   |
| 2     | 77.6352887   |
| 3     | 117.7832018  |
| 4     | 136.9033684  |
| 5     | 150.9884571  |
| 6     | 167.4349824  |
| 7     | 198.0703033  |
| 8     | 257.6352887  |
| 9     | 297.7832018  |
| 10    | 316.9033684  |
| 11    | 330.9884571  |
| 12    | 347.4349824  |
| Asc   | 18.0703033   |
| MC    | 316.9033684  |
| ARMC  | 319.3547724  |
| Vertex| 236.2978498  |

**Julian Day:** `swe_julday(2000, 1, 1, 12.0, SE_GREG_CAL)` = 2451545.0 (J2000.0 epoch, exact by definition)

---

## File Structure

```
swisseph.dart/
├── pubspec.yaml                       # Package manifest with build hook config
├── analysis_options.yaml              # Dart lint rules
├── .gitignore
├── LICENSE                            # AGPL-3.0 (matching swisseph C library)
├── lib/
│   ├── swisseph.dart                  # Barrel export (SwissEph + constants + types)
│   └── src/
│       ├── swiss_eph.dart             # SwissEph class: public API, Arena memory mgmt
│       ├── bindings.dart              # SweBindings: raw dart:ffi function lookups
│       ├── constants.dart             # Body IDs, flags, house system codes, ayanamsas
│       └── types.dart                 # CalcResult, HouseResult record types
├── hook/
│   └── build.dart                     # Native asset build hook (compiles C → .so)
├── test/
│   ├── date_test.dart                 # julday / revjul tests
│   ├── calc_test.dart                 # swe_calc_ut planet position tests
│   ├── houses_test.dart               # swe_houses tests
│   ├── ayanamsa_test.dart             # Sidereal mode + ayanamsa tests
│   └── isolate_test.dart              # Concurrent isolate safety proof
└── example/
    └── example.dart                   # Usage demo
```

**File responsibilities:**

| File | Responsibility |
|------|---------------|
| `lib/src/bindings.dart` | Raw `dart:ffi` lookups — one late final per C function. Private to package. |
| `lib/src/swiss_eph.dart` | Public API. Each method: allocate via Arena → call binding → marshal result → return. Instance-based (owns its own DynamicLibrary). |
| `lib/src/constants.dart` | All `SE_*` int constants from swephexp.h. Abstract classes with static const fields, grouped by domain. |
| `lib/src/types.dart` | Dart record types for multi-value returns (CalcResult, HouseResult, etc.). |
| `hook/build.dart` | Finds C source at `../swisseph/` (sibling directory) or `SWISSEPH_SRC` env var, compiles 9 .c files via CBuilder. |

---

## Tasks

### Task 1: Project Scaffold

**Files:**
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`
- Create: `.gitignore`
- Create: `lib/swisseph.dart` (placeholder barrel)

- [ ] **Step 1: Initialize git repo**

```bash
cd /home/josh/nhs/soft/swisseph.dart
git init
```

- [ ] **Step 2: Create pubspec.yaml**

```yaml
name: swisseph
description: Isolate-safe Dart FFI bindings to the Swiss Ephemeris C library.
version: 0.1.0
repository: https://gitlab.com/ninthhouse/swisseph.dart

environment:
  sdk: ^3.11.0

dependencies:
  ffi: ^2.2.0
  logging: any

dev_dependencies:
  test: ^1.25.6
  hooks: any
  code_assets: any
  native_toolchain_c: any

hook:
  build:
    enabled: true
```

- [ ] **Step 3: Create analysis_options.yaml**

```yaml
analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
  errors:
    unused_import: warning
    unused_local_variable: warning
```

- [ ] **Step 4: Create .gitignore**

```
.dart_tool/
build/
pubspec.lock
*.so
*.dylib
*.dll
```

- [ ] **Step 5: Create placeholder barrel**

Create `lib/swisseph.dart`:

```dart
/// Isolate-safe Dart FFI bindings to the Swiss Ephemeris C library.
library swisseph;
```

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml analysis_options.yaml .gitignore lib/swisseph.dart
git commit -m "scaffold: init swisseph.dart package"
```

---

### Task 2: Build Hook

**Files:**
- Create: `hook/build.dart`

**Context:** The build hook compiles the Swiss Ephemeris C source into a shared library (.so/.dylib/.dll) during `dart pub get`. It looks for the C source in the sibling `swisseph/` directory (the fork at `/home/josh/nhs/soft/swisseph/`). This is the same approach as sweph.dart's hook but pointing at our fork instead of the pub cache.

**Reference:** `/home/josh/nhs/soft/sweph.dart/sweph_demo/hook/build.dart` for the hook API pattern.

- [ ] **Step 1: Create hook/build.dart**

```dart
import 'dart:io';
import 'package:hooks/hooks.dart';
import 'package:code_assets/code_assets.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:logging/logging.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    hierarchicalLoggingEnabled = true;
    final logger = Logger('swisseph_build')
      ..level = Level.ALL
      ..onRecord.listen((record) {
        print('${record.level.name}: ${record.message}');
      });

    final srcDir = _findSourceDir();
    logger.info('Swiss Ephemeris C source: $srcDir');

    final sources = [
      'sweph.c',
      'swephlib.c',
      'swecl.c',
      'swehouse.c',
      'swehel.c',
      'swejpl.c',
      'swemmoon.c',
      'swemplan.c',
      'swedate.c',
    ].map((f) => '$srcDir/$f').toList();

    final cBuilder = CBuilder.library(
      name: 'swisseph',
      assetName: 'swisseph',
      sources: sources,
      language: Language.c,
      optimizationLevel: OptimizationLevel.o2,
    );

    await cBuilder.run(input: input, output: output, logger: logger);
    logger.info('Build completed successfully');
  });
}

/// Find the Swiss Ephemeris C source directory.
/// Priority: SWISSEPH_SRC env var > sibling directory relative to package root.
String _findSourceDir() {
  final envSrc = Platform.environment['SWISSEPH_SRC'];
  if (envSrc != null && Directory(envSrc).existsSync()) {
    return envSrc;
  }

  // Resolve relative to this script's location (hook/build.dart),
  // so we go up two levels to the package root's parent.
  final scriptDir = File(Platform.script.toFilePath()).parent; // hook/
  final packageRoot = scriptDir.parent; // swisseph.dart/
  final parentDir = packageRoot.parent; // parent of swisseph.dart/

  final sibling = Directory('${parentDir.path}/swisseph');
  if (sibling.existsSync() &&
      File('${sibling.path}/swephexp.h').existsSync()) {
    return sibling.path;
  }

  throw Exception(
    'Swiss Ephemeris C source not found. '
    'Set SWISSEPH_SRC environment variable or place swisseph/ as a sibling directory of swisseph.dart/.',
  );
}
```

- [ ] **Step 2: Run dart pub get to trigger build**

```bash
cd /home/josh/nhs/soft/swisseph.dart
dart pub get
```

Expected: Build hook compiles 9 C files, produces `.dart_tool/lib/libswisseph.so` (or similar path).

- [ ] **Step 3: Verify the .so was built**

```bash
find .dart_tool -name '*.so' -o -name '*.dylib' 2>/dev/null
```

Expected: At least one `libswisseph.so` file.

- [ ] **Step 4: Commit**

```bash
git add hook/build.dart
git commit -m "build: add native asset hook to compile Swiss Ephemeris C source"
```

---

### Task 3: Constants

**Files:**
- Create: `lib/src/constants.dart`

**Context:** These are direct translations of the `#define` constants from `swephexp.h` and `sweodef.h`. Use abstract final classes with static const fields (Dart idiom for constant namespaces). Only include constants needed for the initial ~15 functions plus the ones Arrow will use. More can be added incrementally.

**Reference:** `/home/josh/nhs/soft/swisseph/swephexp.h` (lines with `#define SE_*`)

- [ ] **Step 1: Create lib/src/constants.dart**

```dart
/// Swiss Ephemeris constants translated from swephexp.h and sweodef.h.

// --- Ephemeris selection ---

/// Swiss Ephemeris data files (highest precision)
const int seFlgSwiEph = 2;

/// Moshier analytical ephemeris (no files needed, ~1" accuracy)
const int seFlgMosEph = 4;

/// JPL ephemeris files
const int seFlgJplEph = 1;

// --- Calculation flags ---

/// Include speed in output
const int seFlgSpeed = 256;

/// Heliocentric positions
const int seFlgHelCtr = 8;

/// True position (no aberration/deflection)
const int seFlgTruePos = 16;

/// Equatorial coordinates (RA/dec instead of lon/lat)
const int seFlgEquatorial = 2048;

/// Topocentric (requires swe_set_topo)
const int seFlgTopoCtr = 32768;

/// Sidereal zodiac (requires swe_set_sid_mode)
const int seFlgSidereal = 65536;

/// No aberration correction
const int seFlgNoAberr = 1024;

/// No gravitational deflection
const int seFlgNoGdefl = 512;

/// Cartesian (XYZ) instead of polar
const int seFlgXyz = 4096;

/// Radians instead of degrees
const int seFlgRadians = 8192;

/// Barycentric
const int seFlgBaryCtr = 16384;

/// ICRS reference frame
const int seFlgIcrs = 131072;

// --- Body IDs ---

const int seSun = 0;
const int seMoon = 1;
const int seMercury = 2;
const int seVenus = 3;
const int seMars = 4;
const int seJupiter = 5;
const int seSaturn = 6;
const int seUranus = 7;
const int seNeptune = 8;
const int sePluto = 9;
const int seMeanNode = 10;
const int seTrueNode = 11;
const int seMeanApog = 12;
const int seOscuApog = 13;
const int seEarth = 14;
const int seChiron = 15;
const int sePholus = 16;
const int seCeres = 17;
const int sePallas = 18;
const int seJuno = 19;
const int seVesta = 20;
const int seIntpApog = 21;
const int seIntpPerg = 22;

/// Offset for numbered asteroids: body = seAstOffset + asteroid_number
const int seAstOffset = 10000;

/// Hamburger School (Uranian) fictitious bodies
const int seCupido = 40;
const int seHades = 41;
const int seZeus = 42;
const int seKronos = 43;
const int seApollon = 44;
const int seAdmetos = 45;
const int seVulkanus = 46;
const int sePoseidon = 47;

// --- Calendar type ---

const int seGregCal = 1;
const int seJulCal = 0;

// --- House system codes (ASCII values) ---

/// Placidus
const int hsysPlacidus = 0x50; // 'P'

/// Koch
const int hsysKoch = 0x4B; // 'K'

/// Porphyry
const int hsysPorphyry = 0x4F; // 'O'

/// Regiomontanus
const int hsysRegiomontanus = 0x52; // 'R'

/// Campanus
const int hsysCampanus = 0x43; // 'C'

/// Equal (cusp 1 = Asc)
const int hsysEqual = 0x45; // 'E'

/// Whole Sign
const int hsysWholeSign = 0x57; // 'W'

/// Alcabitius
const int hsysAlcabitius = 0x42; // 'B'

/// Topocentric (Polich-Page)
const int hsysTopocentric = 0x54; // 'T'

/// Meridian (Axial)
const int hsysMeridian = 0x58; // 'X'

/// Morinus
const int hsysMorinus = 0x4D; // 'M'

/// Krusinski-Pisa
const int hsysKrusinski = 0x55; // 'U'

/// Vehlow equal
const int hsysVehlow = 0x56; // 'V'

// --- Ayanamsa modes ---

const int seSidmFaganBradley = 0;
const int seSidmLahiri = 1;
const int seSidmDeluce = 2;
const int seSidmRaman = 3;
const int seSidmUshashashi = 4;
const int seSidmKrishnamurti = 5;
const int seSidmDjwhalKhul = 6;
const int seSidmYukteshwar = 7;
const int seSidmJnBhasin = 8;
const int seSidmBabylKugler1 = 9;
const int seSidmBabylKugler2 = 10;
const int seSidmBabylKugler3 = 11;
const int seSidmBabylHuber = 12;
const int seSidmBabylEtpsc = 13;
const int seSidmAldebaran15tau = 14;
const int seSidmHipparchos = 15;
const int seSidmSassanian = 16;
const int seSidmGalcent0sag = 17;
const int seSidmJ2000 = 18;
const int seSidmJ1900 = 19;
const int seSidmB1950 = 20;
const int seSidmSuryasiddhanta = 21;
const int seSidmSuryasiddhantaMsun = 22;
const int seSidmAryabhata = 23;
const int seSidmAryabhataMsun = 24;
const int seSidmSsRevati = 25;
const int seSidmSsCitra = 26;
const int seSidmTrueCitra = 27;
const int seSidmTrueRevati = 28;
const int seSidmTruePushya = 29;
const int seSidmGalcentRgilbrand = 30;
const int seSidmGalequIau1958 = 31;
const int seSidmGalequTrue = 32;
const int seSidmGalequMula = 33;
const int seSidmGalalignMardyks = 34;
const int seSidmTrueMula = 35;
const int seSidmGalcentMulaWilhelm = 36;
const int seSidmAryabhata522 = 37;
const int seSidmBabylBritton = 38;
const int seSidmTrueSheoran = 39;
const int seSidmGalcentCochrane = 40;
const int seSidmGalequFiorenza = 41;
const int seSidmValensMoon = 42;
const int seSidmLahiri1940 = 43;
const int seSidmLahiriVp285 = 44;
const int seSidmKrishnamurtiVp291 = 45;
const int seSidmLahiriIcrc = 46;

/// User-defined ayanamsa
const int seSidmUser = 255;

// --- Rise/set flags ---

const int seCalcRise = 1;
const int seCalcSet = 2;
const int seCalcMTransit = 4;
const int seCalcITransit = 8;
const int seBitDiscCenter = 256;
const int seBitDiscBottom = 8192;
const int seBitNoRefraction = 512;
const int seBitHinduRising = 896; // disc center + no refraction + geocentric no ecl lat
```

- [ ] **Step 2: Commit**

```bash
git add lib/src/constants.dart
git commit -m "feat: add Swiss Ephemeris constants (bodies, flags, houses, ayanamsas)"
```

---

### Task 4: Return Types

**Files:**
- Create: `lib/src/types.dart`

**Context:** Simple Dart record types for functions that return multiple values via pointers in C. Keep them minimal — no methods, just data.

- [ ] **Step 1: Create lib/src/types.dart**

```dart
/// Return type for swe_calc_ut / swe_calc.
/// The xx[6] array: longitude, latitude, distance, speed in lon, speed in lat, speed in dist.
class CalcResult {
  final double longitude;
  final double latitude;
  final double distance;
  final double longitudeSpeed;
  final double latitudeSpeed;
  final double distanceSpeed;

  /// The return flag from swe_calc_ut (indicates which flags were actually computed).
  final int returnFlag;

  const CalcResult({
    required this.longitude,
    required this.latitude,
    required this.distance,
    required this.longitudeSpeed,
    required this.latitudeSpeed,
    required this.distanceSpeed,
    required this.returnFlag,
  });

  @override
  String toString() =>
      'CalcResult(lon: $longitude, lat: $latitude, dist: $distance, '
      'lonSpd: $longitudeSpeed, latSpd: $latitudeSpeed, distSpd: $distanceSpeed)';
}

/// Return type for swe_houses / swe_houses_ex.
class HouseResult {
  /// House cusps. Index 0 is unused (C convention); cusps[1] through cusps[12]
  /// are the 12 house cusps. For Gauquelin sectors, cusps[1]–cusps[36].
  final List<double> cusps;

  /// Ascendant, MC, and related points.
  /// [0] Ascendant, [1] MC, [2] ARMC, [3] Vertex,
  /// [4] equatorial ascendant, [5] co-ascendant (Koch),
  /// [6] co-ascendant (Munkasey), [7] polar ascendant.
  final List<double> ascmc;

  /// Return flag.
  final int returnFlag;

  const HouseResult({
    required this.cusps,
    required this.ascmc,
    required this.returnFlag,
  });

  double get ascendant => ascmc[0];
  double get mc => ascmc[1];
  double get armc => ascmc[2];
  double get vertex => ascmc[3];
}

/// Return type for swe_get_ayanamsa_ex_ut.
class AyanamsaResult {
  final double ayanamsa;
  final int returnFlag;

  const AyanamsaResult({required this.ayanamsa, required this.returnFlag});
}

/// Return type for swe_revjul.
class DateResult {
  final int year;
  final int month;
  final int day;
  final double hour;

  const DateResult({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
  });

  @override
  String toString() => 'DateResult($year-$month-$day ${hour}h)';
}

/// Return type for swe_rise_trans.
class RiseTransResult {
  final double transitTime;
  final int returnFlag;

  const RiseTransResult({
    required this.transitTime,
    required this.returnFlag,
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/src/types.dart
git commit -m "feat: add return types (CalcResult, HouseResult, DateResult, etc.)"
```

---

### Task 5: Raw FFI Bindings

**Files:**
- Create: `lib/src/bindings.dart`

**Context:** This is the low-level dart:ffi binding class. Each C function gets a `late final` function pointer looked up from the DynamicLibrary. This class is private to the package — only `SwissEph` uses it.

**Reference for type signatures:** `/home/josh/nhs/soft/swisseph/swephexp.h` and `/home/josh/nhs/soft/sweph.dart/sweph.dart/lib/src/bindings.dart`

**Key dart:ffi type mappings:**
- C `int32` / `int` → `ffi.Int32` (native) / `int` (dart)
- C `double` → `ffi.Double` (native) / `double` (dart)
- C `double *` → `ffi.Pointer<ffi.Double>`
- C `char *` → `ffi.Pointer<ffi.Char>`
- C `const char *` → `ffi.Pointer<ffi.Char>`
- C `void` → `ffi.Void`

- [ ] **Step 1: Create lib/src/bindings.dart**

```dart
import 'dart:ffi' as ffi;

/// Raw dart:ffi bindings to Swiss Ephemeris C functions.
///
/// Each function is looked up lazily from the DynamicLibrary.
/// This class is private to the package — use [SwissEph] instead.
class SweBindings {
  final ffi.DynamicLibrary _lib;

  SweBindings(this._lib);

  // --- Date/time ---

  late final swe_julday = _lib
      .lookupFunction<
          ffi.Double Function(
              ffi.Int32, ffi.Int32, ffi.Int32, ffi.Double, ffi.Int32),
          double Function(int, int, int, double, int)>('swe_julday');

  late final swe_revjul = _lib.lookupFunction<
      ffi.Void Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Double>),
      void Function(double, int, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Double>)>('swe_revjul');

  // --- Configuration ---

  late final swe_set_ephe_path = _lib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Char>),
      void Function(ffi.Pointer<ffi.Char>)>('swe_set_ephe_path');

  late final swe_set_sid_mode = _lib.lookupFunction<
      ffi.Void Function(ffi.Int32, ffi.Double, ffi.Double),
      void Function(int, double, double)>('swe_set_sid_mode');

  late final swe_set_topo = _lib.lookupFunction<
      ffi.Void Function(ffi.Double, ffi.Double, ffi.Double),
      void Function(double, double, double)>('swe_set_topo');

  late final swe_close = _lib
      .lookupFunction<ffi.Void Function(), void Function()>('swe_close');

  late final swe_version = _lib.lookupFunction<
      ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>),
      ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)>('swe_version');

  // --- Calculations ---

  late final swe_calc_ut = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Char>),
      int Function(double, int, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Char>)>('swe_calc_ut');

  late final swe_houses = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Double, ffi.Double, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>),
      int Function(double, double, double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>)>('swe_houses');

  // --- Ayanamsa ---

  late final swe_get_ayanamsa_ut = _lib.lookupFunction<
      ffi.Double Function(ffi.Double),
      double Function(double)>('swe_get_ayanamsa_ut');

  late final swe_get_ayanamsa_ex_ut = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Char>),
      int Function(double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Char>)>('swe_get_ayanamsa_ex_ut');

  late final swe_get_ayanamsa_name = _lib.lookupFunction<
      ffi.Pointer<ffi.Char> Function(ffi.Int32),
      ffi.Pointer<ffi.Char> Function(int)>('swe_get_ayanamsa_name');

  // --- Names ---

  late final swe_get_planet_name = _lib.lookupFunction<
      ffi.Pointer<ffi.Char> Function(ffi.Int32, ffi.Pointer<ffi.Char>),
      ffi.Pointer<ffi.Char> Function(
          int, ffi.Pointer<ffi.Char>)>('swe_get_planet_name');

  late final swe_house_name = _lib.lookupFunction<
      ffi.Pointer<ffi.Char> Function(ffi.Int32),
      ffi.Pointer<ffi.Char> Function(int)>('swe_house_name');

  // --- Rise/set ---

  late final swe_rise_trans = _lib.lookupFunction<
      ffi.Int32 Function(
          ffi.Double,
          ffi.Int32,
          ffi.Pointer<ffi.Char>,
          ffi.Int32,
          ffi.Int32,
          ffi.Pointer<ffi.Double>,
          ffi.Double,
          ffi.Double,
          ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Char>),
      int Function(
          double,
          int,
          ffi.Pointer<ffi.Char>,
          int,
          int,
          ffi.Pointer<ffi.Double>,
          double,
          double,
          ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Char>)>('swe_rise_trans');

  // --- Utilities ---

  late final swe_degnorm = _lib.lookupFunction<
      ffi.Double Function(ffi.Double),
      double Function(double)>('swe_degnorm');
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/src/bindings.dart
git commit -m "feat: add raw FFI bindings for ~15 Swiss Ephemeris functions"
```

---

### Task 6: SwissEph Class — Core + Date/Time

**Files:**
- Create: `lib/src/swiss_eph.dart`
- Create: `test/date_test.dart`

**Context:** The public API class. Instance-based — each `SwissEph` wraps its own `DynamicLibrary`. This task implements the constructor, close, version, and date/time functions. Uses `dart:ffi` Arena for all native memory allocation (auto-freed when scope exits).

- [ ] **Step 1: Write the failing test**

Create `test/date_test.dart`:

```dart
import 'dart:io';
import 'package:test/test.dart';
import 'package:swisseph/swisseph.dart';

void main() {
  late SwissEph swe;

  setUp(() {
    swe = SwissEph.find();
  });

  tearDown(() {
    swe.close();
  });

  group('version', () {
    test('returns a non-empty version string', () {
      final v = swe.version();
      expect(v, isNotEmpty);
      expect(v, contains('.'));
    });
  });

  group('julday', () {
    test('J2000.0 epoch', () {
      final jd = swe.julday(2000, 1, 1, 12.0);
      expect(jd, equals(2451545.0));
    });

    test('known date: 1985-01-01 00:00', () {
      final jd = swe.julday(1985, 1, 1, 0.0);
      expect(jd, equals(2446066.5));
    });
  });

  group('revjul', () {
    test('J2000.0 epoch roundtrip', () {
      final result = swe.revjul(2451545.0);
      expect(result.year, equals(2000));
      expect(result.month, equals(1));
      expect(result.day, equals(1));
      expect(result.hour, closeTo(12.0, 1e-10));
    });

    test('julday/revjul roundtrip', () {
      final jd = swe.julday(1990, 6, 15, 18.5);
      final result = swe.revjul(jd);
      expect(result.year, equals(1990));
      expect(result.month, equals(6));
      expect(result.day, equals(15));
      expect(result.hour, closeTo(18.5, 1e-10));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
dart test test/date_test.dart
```

Expected: Compilation error — `SwissEph` class doesn't exist yet.

- [ ] **Step 3: Implement SwissEph class**

Create `lib/src/swiss_eph.dart`:

```dart
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart' as pkg_ffi;

import 'bindings.dart';
import 'types.dart';
import 'constants.dart';

/// An instance of the Swiss Ephemeris C library.
///
/// Each instance wraps its own [ffi.DynamicLibrary] and thus its own
/// C global state. For isolate safety, load from unique .so paths —
/// `dlopen` deduplicates by device+inode, so the same file path means
/// shared globals across isolates. Copy the .so to a unique path per isolate.
///
/// **Warning: Global state drifts across await points.** Even with unique
/// .so copies, always re-set configuration (setSidMode, setEphePath, setTopo)
/// immediately before each calculation batch. Do NOT assume state set before
/// an `await` will persist after it.
///
/// Usage:
/// ```dart
/// final swe = SwissEph.find();
/// swe.setEphePath('/path/to/ephe');
/// final jd = swe.julday(2000, 1, 1, 12.0);
/// final result = swe.calcUt(jd, seSun, seFlgSwiEph | seFlgSpeed);
/// print(result.longitude);
/// swe.close();
/// ```
class SwissEph {
  late final ffi.DynamicLibrary _lib;
  late final SweBindings _bind;

  /// Load the Swiss Ephemeris library.
  ///
  /// [libraryPath] is the path to the compiled shared library (.so/.dylib/.dll).
  /// This is required because each instance needs its own DynamicLibrary for
  /// isolate safety. For convenience, use [SwissEph.find()] which searches
  /// common build output locations.
  SwissEph(String libraryPath) {
    _lib = ffi.DynamicLibrary.open(libraryPath);
    _bind = SweBindings(_lib);
  }

  /// Search for the built library in common locations and load it.
  ///
  /// Looks in: .dart_tool/ (build hook output), LD_LIBRARY_PATH, current dir.
  /// Throws [StateError] if not found.
  factory SwissEph.find() {
    final path = findLibrary();
    return SwissEph(path);
  }

  /// Search for the compiled Swiss Ephemeris shared library.
  ///
  /// Searches .dart_tool/ recursively for libswisseph.so or libswisseph.dylib.
  /// Returns the absolute path. Throws [StateError] if not found.
  static String findLibrary() {
    final dartTool = Directory('.dart_tool');
    if (dartTool.existsSync()) {
      for (final entity in dartTool.listSync(recursive: true)) {
        if (entity is File &&
            (entity.path.endsWith('libswisseph.so') ||
             entity.path.endsWith('libswisseph.dylib') ||
             entity.path.endsWith('swisseph.dll'))) {
          return entity.path;
        }
      }
    }
    throw StateError(
      'libswisseph not found. Run "dart pub get" to trigger the build hook, '
      'or pass an explicit path to SwissEph().',
    );
  }

  /// Close the library and free C-side resources.
  /// Call this when done to release file handles and caches.
  void close() {
    _bind.swe_close();
  }

  /// Get the Swiss Ephemeris library version string.
  String version() {
    final buf = pkg_ffi.calloc<ffi.Char>(256);
    try {
      _bind.swe_version(buf);
      return buf.cast<pkg_ffi.Utf8>().toDartString();
    } finally {
      pkg_ffi.calloc.free(buf);
    }
  }

  // --- Date/time ---

  /// Convert a calendar date to Julian Day number.
  ///
  /// [year], [month], [day] as integers; [hour] as decimal hours (e.g. 12.5 = 12:30).
  /// [gregorian] selects Gregorian (true, default) or Julian (false) calendar.
  double julday(int year, int month, int day, double hour,
      {bool gregorian = true}) {
    return _bind.swe_julday(
        year, month, day, hour, gregorian ? seGregCal : seJulCal);
  }

  /// Convert a Julian Day number back to a calendar date.
  DateResult revjul(double jd, {bool gregorian = true}) {
    final pYear = pkg_ffi.calloc<ffi.Int32>();
    final pMonth = pkg_ffi.calloc<ffi.Int32>();
    final pDay = pkg_ffi.calloc<ffi.Int32>();
    final pHour = pkg_ffi.calloc<ffi.Double>();
    try {
      _bind.swe_revjul(
          jd, gregorian ? seGregCal : seJulCal, pYear, pMonth, pDay, pHour);
      return DateResult(
        year: pYear.value,
        month: pMonth.value,
        day: pDay.value,
        hour: pHour.value,
      );
    } finally {
      pkg_ffi.calloc.free(pYear);
      pkg_ffi.calloc.free(pMonth);
      pkg_ffi.calloc.free(pDay);
      pkg_ffi.calloc.free(pHour);
    }
  }
}
```

**Note:** This uses `package:ffi` for `calloc` and `Utf8` utilities — already in pubspec.yaml from Task 1.

- [ ] **Step 4: Update barrel export**

Update `lib/swisseph.dart`:

```dart
/// Isolate-safe Dart FFI bindings to the Swiss Ephemeris C library.
library swisseph;

export 'src/swiss_eph.dart';
export 'src/constants.dart';
export 'src/types.dart';
```

- [ ] **Step 5: Run tests**

```bash
dart pub get
dart test test/date_test.dart -v
```

Expected: All tests pass. If build hook fails to register native asset properly, you may need to find the .so path manually and pass it to `SwissEph(libraryPath: '...')`.

**Troubleshooting:** If `DynamicLibrary.open('swisseph')` fails, the build hook may not register the asset correctly. Find the built .so with `find .dart_tool -name '*swisseph*'` and use the explicit path. The native asset system should handle this automatically but if not, adjust the test setUp to use an explicit path.

- [ ] **Step 6: Commit**

```bash
git add lib/ test/date_test.dart pubspec.yaml
git commit -m "feat: SwissEph class with version, julday, revjul + tests"
```

---

### Task 7: SwissEph — Configuration Methods

**Files:**
- Modify: `lib/src/swiss_eph.dart`

**Context:** Add setEphePath, setSidMode, setTopo to SwissEph. These modify C global state. No separate tests for these — they'll be tested implicitly through calc and ayanamsa tests (you can't observe their effect without calculating).

- [ ] **Step 1: Add config methods to SwissEph**

Add to `lib/src/swiss_eph.dart` after the `revjul` method:

```dart
  // --- Configuration ---

  /// Set the directory path for Swiss Ephemeris data files (.se1).
  ///
  /// Must be called before calculations that use SEFLG_SWIEPH.
  /// The path should contain files like sepl_18.se1, semo_18.se1, etc.
  void setEphePath(String path) {
    final pPath = path.toNativeUtf8(allocator: pkg_ffi.calloc).cast<ffi.Char>();
    try {
      _bind.swe_set_ephe_path(pPath);
    } finally {
      pkg_ffi.calloc.free(pPath);
    }
  }

  /// Set the sidereal mode (ayanamsa).
  ///
  /// [sidMode] is one of the SE_SIDM_* constants (e.g. [seSidmLahiri]).
  /// [t0] and [ayanT0] are only used with [seSidmUser] for custom ayanamsa.
  ///
  /// After calling this, use [seFlgSidereal] flag in [calcUt] for sidereal positions,
  /// or call [getAyanamsaUt] to get the ayanamsa value.
  void setSidMode(int sidMode, {double t0 = 0, double ayanT0 = 0}) {
    _bind.swe_set_sid_mode(sidMode, t0, ayanT0);
  }

  /// Set the geographic position for topocentric calculations.
  ///
  /// [geolon] geographic longitude in degrees (east positive).
  /// [geolat] geographic latitude in degrees (north positive).
  /// [geoalt] altitude above sea level in meters.
  ///
  /// After calling this, use [seFlgTopoCtr] flag in [calcUt].
  void setTopo(double geolon, double geolat, double geoalt) {
    _bind.swe_set_topo(geolon, geolat, geoalt);
  }
```

**Note:** `toNativeUtf8()` is an extension from `package:ffi`. The memory it allocates must be freed manually.

- [ ] **Step 2: Commit**

```bash
git add lib/src/swiss_eph.dart
git commit -m "feat: add setEphePath, setSidMode, setTopo config methods"
```

---

### Task 8: SwissEph — calcUt + Tests

**Files:**
- Modify: `lib/src/swiss_eph.dart`
- Create: `test/calc_test.dart`

**Context:** `swe_calc_ut` is the core calculation function — it computes a body's position at a given Julian Day (UT). Returns 6 doubles in an array (lon, lat, dist, speeds) plus a return flag. Error messages go into a char[256] buffer.

- [ ] **Step 1: Write the failing test**

Create `test/calc_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:swisseph/swisseph.dart';

void main() {
  late SwissEph swe;

  setUp(() {
    swe = SwissEph.find();
    // Use Moshier ephemeris (no files needed)
    // No setEphePath call → defaults to Moshier
  });

  tearDown(() {
    swe.close();
  });

  group('calcUt', () {
    test('Sun position at J2000 (Moshier)', () {
      // 2000-01-01 00:00 UT
      final jd = swe.julday(2000, 1, 1, 0.0);
      final result = swe.calcUt(jd, seSun, seFlgMosEph | seFlgSpeed);

      // Moshier values (from swetest without -edir):
      // Sun 279.8584626, speed 1.0193448
      expect(result.longitude, closeTo(279.858, 0.01));
      expect(result.longitudeSpeed, closeTo(1.019, 0.01));
    });

    test('Moon position at J2000 (Moshier)', () {
      final jd = swe.julday(2000, 1, 1, 0.0);
      final result = swe.calcUt(jd, seMoon, seFlgMosEph | seFlgSpeed);

      // Moon 217.2844253, speed 12.1030939
      expect(result.longitude, closeTo(217.284, 0.01));
      expect(result.longitudeSpeed, closeTo(12.103, 0.01));
    });

    test('all classical planets return valid longitudes', () {
      final jd = swe.julday(2000, 1, 1, 0.0);
      for (final body in [
        seSun, seMoon, seMercury, seVenus, seMars, seJupiter, seSaturn
      ]) {
        final result = swe.calcUt(jd, body, seFlgMosEph | seFlgSpeed);
        expect(result.longitude, greaterThanOrEqualTo(0.0));
        expect(result.longitude, lessThan(360.0));
        expect(result.returnFlag, isNonNegative,
            reason: 'Negative return flag indicates error for body $body');
      }
    });

    test('returns error string for invalid body', () {
      final jd = swe.julday(2000, 1, 1, 0.0);
      // Body -2 is invalid
      expect(
        () => swe.calcUt(jd, -2, seFlgMosEph),
        throwsA(isA<SweException>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
dart test test/calc_test.dart -v
```

Expected: Fails — `calcUt` and `SweException` don't exist yet.

- [ ] **Step 3: Add SweException to types.dart**

Add to `lib/src/types.dart`:

```dart
/// Exception thrown when a Swiss Ephemeris function reports an error.
class SweException implements Exception {
  final String message;
  final int returnFlag;

  const SweException(this.message, this.returnFlag);

  @override
  String toString() => 'SweException($returnFlag): $message';
}
```

- [ ] **Step 4: Implement calcUt in SwissEph**

Add to `lib/src/swiss_eph.dart`:

```dart
  // --- Calculations ---

  /// Calculate the position of a celestial body at a given Julian Day (UT).
  ///
  /// [jdUt] Julian Day in Universal Time.
  /// [body] one of the SE body constants (e.g. [seSun], [seMoon]).
  /// [flags] combination of SEFLG_* flags (e.g. `seFlgSwiEph | seFlgSpeed`).
  ///
  /// Returns a [CalcResult] with longitude, latitude, distance, and speeds.
  /// Throws [SweException] if the calculation fails (negative return flag).
  CalcResult calcUt(double jdUt, int body, int flags) {
    final xx = pkg_ffi.calloc<ffi.Double>(6);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_calc_ut(jdUt, body, flags, xx, serr);
      if (ret < 0) {
        final msg = serr.cast<pkg_ffi.Utf8>().toDartString();
        throw SweException(msg, ret);
      }
      return CalcResult(
        longitude: xx[0],
        latitude: xx[1],
        distance: xx[2],
        longitudeSpeed: xx[3],
        latitudeSpeed: xx[4],
        distanceSpeed: xx[5],
        returnFlag: ret,
      );
    } finally {
      pkg_ffi.calloc.free(xx);
      pkg_ffi.calloc.free(serr);
    }
  }
```

- [ ] **Step 5: Run tests**

```bash
dart test test/calc_test.dart -v
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/src/swiss_eph.dart lib/src/types.dart test/calc_test.dart
git commit -m "feat: add calcUt with planet position tests"
```

---

### Task 9: SwissEph — houses + Tests

**Files:**
- Modify: `lib/src/swiss_eph.dart`
- Create: `test/houses_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/houses_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:swisseph/swisseph.dart';

void main() {
  late SwissEph swe;

  setUp(() {
    swe = SwissEph.find();
  });

  tearDown(() {
    swe.close();
  });

  group('houses', () {
    test('Campanus houses at J2000 noon, Washington DC', () {
      // 2000-01-01 12:00 UT
      final jd = swe.julday(2000, 1, 1, 12.0);
      final result = swe.houses(jd, 38.8977, -77.0365, hsysCampanus);

      // Reference values from swetest -b1.1.2000 -ut12:00 -house38.8977,-77.0365,C
      expect(result.cusps[1], closeTo(18.0703, 0.001));
      expect(result.cusps[4], closeTo(136.9034, 0.001));
      expect(result.cusps[7], closeTo(198.0703, 0.001));
      expect(result.cusps[10], closeTo(316.9034, 0.001));
      expect(result.ascendant, closeTo(18.0703, 0.001));
      expect(result.mc, closeTo(316.9034, 0.001));
      expect(result.armc, closeTo(319.3548, 0.001));
      expect(result.vertex, closeTo(236.2978, 0.001));
    });

    test('Whole Sign houses have 30-degree spacing from Asc sign', () {
      final jd = swe.julday(2000, 1, 1, 12.0);
      final result = swe.houses(jd, 38.8977, -77.0365, hsysWholeSign);

      // Whole sign: cusp 1 = start of the sign containing the Ascendant.
      // Each subsequent cusp is 30° further.
      final signStart = (result.ascendant ~/ 30) * 30.0;
      expect(result.cusps[1], closeTo(signStart, 0.001));
      for (var i = 2; i <= 12; i++) {
        final expected = (signStart + (i - 1) * 30.0) % 360.0;
        expect(result.cusps[i], closeTo(expected, 0.001));
      }
    });

    test('cusps list has 13 elements (index 0 unused)', () {
      final jd = swe.julday(2000, 1, 1, 12.0);
      final result = swe.houses(jd, 38.8977, -77.0365, hsysCampanus);
      expect(result.cusps.length, equals(13));
    });

    test('ascmc list has 10 elements', () {
      final jd = swe.julday(2000, 1, 1, 12.0);
      final result = swe.houses(jd, 38.8977, -77.0365, hsysCampanus);
      expect(result.ascmc.length, equals(10));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
dart test test/houses_test.dart -v
```

Expected: Fails — `houses` method doesn't exist.

- [ ] **Step 3: Implement houses in SwissEph**

Add to `lib/src/swiss_eph.dart`:

```dart
  /// Calculate house cusps for a given time and location.
  ///
  /// [jdUt] Julian Day in Universal Time.
  /// [geolat] geographic latitude (north positive).
  /// [geolon] geographic longitude (east positive).
  /// [hsys] house system code — one of the hsys* constants
  ///   (e.g. [hsysCampanus], [hsysWholeSign], [hsysPlacidus]).
  ///
  /// Returns a [HouseResult] with cusps[1]–cusps[12] and ascmc points.
  HouseResult houses(double jdUt, double geolat, double geolon, int hsys) {
    // 13 cusps: index 0 unused, 1-12 are house cusps
    // (37 for Gauquelin, but we allocate 37 to be safe)
    final pCusps = pkg_ffi.calloc<ffi.Double>(37);
    final pAscmc = pkg_ffi.calloc<ffi.Double>(10);
    try {
      final ret = _bind.swe_houses(jdUt, geolat, geolon, hsys, pCusps, pAscmc);
      final cusps = List<double>.generate(13, (i) => pCusps[i]);
      final ascmc = List<double>.generate(10, (i) => pAscmc[i]);
      return HouseResult(cusps: cusps, ascmc: ascmc, returnFlag: ret);
    } finally {
      pkg_ffi.calloc.free(pCusps);
      pkg_ffi.calloc.free(pAscmc);
    }
  }
```

- [ ] **Step 4: Run tests**

```bash
dart test test/houses_test.dart -v
```

Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add lib/src/swiss_eph.dart test/houses_test.dart
git commit -m "feat: add house calculation with Campanus/Whole Sign tests"
```

---

### Task 10: SwissEph — Ayanamsa + Tests

**Files:**
- Modify: `lib/src/swiss_eph.dart`
- Create: `test/ayanamsa_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/ayanamsa_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:swisseph/swisseph.dart';

void main() {
  late SwissEph swe;

  setUp(() {
    swe = SwissEph.find();
  });

  tearDown(() {
    swe.close();
  });

  group('ayanamsa', () {
    test('Lahiri ayanamsa at J2000', () {
      swe.setSidMode(seSidmLahiri);
      // 2000-01-01 00:00 UT
      final jd = swe.julday(2000, 1, 1, 0.0);
      final aya = swe.getAyanamsaUt(jd);

      // Reference: 23°51'11.5325 ≈ 23.8532 degrees
      expect(aya, closeTo(23.853, 0.01));
    });

    test('ayanamsa name for Lahiri', () {
      final name = swe.getAyanamsaName(seSidmLahiri);
      expect(name.toLowerCase(), contains('lahiri'));
    });

    test('sidereal position = tropical - ayanamsa', () {
      swe.setSidMode(seSidmLahiri);
      final jd = swe.julday(2000, 1, 1, 0.0);

      // Get tropical Sun
      final tropical = swe.calcUt(jd, seSun, seFlgMosEph | seFlgSpeed);

      // Get sidereal Sun
      final sidereal = swe.calcUt(
          jd, seSun, seFlgMosEph | seFlgSpeed | seFlgSidereal);

      // Get ayanamsa
      final aya = swe.getAyanamsaUt(jd);

      // sidereal ≈ tropical - ayanamsa (mod 360)
      final expected = (tropical.longitude - aya) % 360;
      expect(sidereal.longitude, closeTo(expected, 0.01));
    });

    test('getAyanamsaExUt returns same as getAyanamsaUt', () {
      swe.setSidMode(seSidmLahiri);
      final jd = swe.julday(2000, 1, 1, 0.0);

      final simple = swe.getAyanamsaUt(jd);
      final extended = swe.getAyanamsaExUt(jd, seFlgMosEph);

      expect(extended.ayanamsa, closeTo(simple, 0.0001));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
dart test test/ayanamsa_test.dart -v
```

Expected: Fails — methods don't exist.

- [ ] **Step 3: Implement ayanamsa methods in SwissEph**

Add to `lib/src/swiss_eph.dart`:

```dart
  // --- Ayanamsa ---

  /// Get the ayanamsa value for a given Julian Day (UT).
  ///
  /// Call [setSidMode] first to select the ayanamsa system.
  double getAyanamsaUt(double jdUt) {
    return _bind.swe_get_ayanamsa_ut(jdUt);
  }

  /// Get the ayanamsa value with extended flags (e.g. ephemeris selection).
  ///
  /// Call [setSidMode] first to select the ayanamsa system.
  AyanamsaResult getAyanamsaExUt(double jdUt, int flags) {
    final pAya = pkg_ffi.calloc<ffi.Double>();
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_get_ayanamsa_ex_ut(jdUt, flags, pAya, serr);
      if (ret < 0) {
        final msg = serr.cast<pkg_ffi.Utf8>().toDartString();
        throw SweException(msg, ret);
      }
      return AyanamsaResult(ayanamsa: pAya.value, returnFlag: ret);
    } finally {
      pkg_ffi.calloc.free(pAya);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Get the name of an ayanamsa mode.
  String getAyanamsaName(int sidMode) {
    final ptr = _bind.swe_get_ayanamsa_name(sidMode);
    return ptr.cast<pkg_ffi.Utf8>().toDartString();
  }
```

- [ ] **Step 4: Run tests**

```bash
dart test test/ayanamsa_test.dart -v
```

Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add lib/src/swiss_eph.dart test/ayanamsa_test.dart
git commit -m "feat: add ayanamsa methods (getAyanamsaUt, getAyanamsaExUt, getAyanamsaName)"
```

---

### Task 11: SwissEph — Names & Utilities

**Files:**
- Modify: `lib/src/swiss_eph.dart`

**Context:** Small methods: getPlanetName, houseName, degnorm. No separate test file — add a few assertions to existing tests or a quick group in date_test.dart.

- [ ] **Step 1: Write failing tests**

Append to `test/date_test.dart` inside the `main()` function:

```dart
  group('names', () {
    test('planet name for Sun', () {
      expect(swe.getPlanetName(seSun), equals('Sun'));
    });

    test('planet name for Moon', () {
      expect(swe.getPlanetName(seMoon), equals('Moon'));
    });

    test('house name for Campanus', () {
      final name = swe.houseName(hsysCampanus);
      expect(name.toLowerCase(), contains('campanus'));
    });
  });

  group('degnorm', () {
    test('normalizes negative degrees', () {
      expect(swe.degnorm(-10.0), closeTo(350.0, 0.001));
    });

    test('normalizes degrees > 360', () {
      expect(swe.degnorm(370.0), closeTo(10.0, 0.001));
    });

    test('passes through valid degrees', () {
      expect(swe.degnorm(180.0), closeTo(180.0, 0.001));
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
dart test test/date_test.dart -v
```

Expected: Fails — `getPlanetName`, `houseName`, `degnorm` don't exist.

- [ ] **Step 3: Implement the methods**

Add to `lib/src/swiss_eph.dart`:

```dart
  // --- Names ---

  /// Get the name of a celestial body.
  String getPlanetName(int body) {
    final buf = pkg_ffi.calloc<ffi.Char>(256);
    try {
      _bind.swe_get_planet_name(body, buf);
      return buf.cast<pkg_ffi.Utf8>().toDartString();
    } finally {
      pkg_ffi.calloc.free(buf);
    }
  }

  /// Get the name of a house system.
  String houseName(int hsys) {
    final ptr = _bind.swe_house_name(hsys);
    return ptr.cast<pkg_ffi.Utf8>().toDartString();
  }

  // --- Utilities ---

  /// Normalize a degree value to 0–360 range.
  double degnorm(double x) {
    return _bind.swe_degnorm(x);
  }
```

- [ ] **Step 4: Run all tests**

```bash
dart test -v
```

Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add lib/src/swiss_eph.dart test/date_test.dart
git commit -m "feat: add getPlanetName, houseName, degnorm"
```

---

### Task 12: SwissEph — riseTrans + Test

**Files:**
- Modify: `lib/src/swiss_eph.dart`

**Context:** `swe_rise_trans` finds the next rise/set/transit of a body. It takes geographic position as a 3-element double array, plus atmospheric conditions. This rounds out the initial ~15 functions.

- [ ] **Step 1: Implement riseTrans**

Add to `lib/src/swiss_eph.dart`:

```dart
  // --- Rise/Set ---

  /// Find the next rise, set, or transit of a celestial body.
  ///
  /// [jdUt] starting Julian Day (UT).
  /// [body] celestial body (SE body constant).
  /// [epheflag] ephemeris flags (e.g. [seFlgSwiEph]).
  /// [rsmi] rise/set/transit flag (e.g. [seCalcRise], [seCalcSet]).
  /// [geolon], [geolat], [geoalt] observer position.
  /// [atpress] atmospheric pressure in mbar (default 1013.25 for standard, 0 for no refraction).
  /// [attemp] atmospheric temperature in °C (default 15).
  ///
  /// Returns the Julian Day (UT) of the event.
  /// Throws [SweException] on error (e.g. body never rises at this location).
  RiseTransResult riseTrans(
    double jdUt,
    int body, {
    int epheflag = seFlgMosEph,
    int rsmi = seCalcRise,
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
  }) {
    final geopos = pkg_ffi.calloc<ffi.Double>(3);
    final tret = pkg_ffi.calloc<ffi.Double>(10);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    final starname = pkg_ffi.calloc<ffi.Char>(256); // empty for planets
    try {
      geopos[0] = geolon;
      geopos[1] = geolat;
      geopos[2] = geoalt;

      final ret = _bind.swe_rise_trans(
          jdUt, body, starname, epheflag, rsmi, geopos, atpress, attemp,
          tret, serr);
      if (ret < 0) {
        final msg = serr.cast<pkg_ffi.Utf8>().toDartString();
        throw SweException(msg, ret);
      }
      return RiseTransResult(transitTime: tret[0], returnFlag: ret);
    } finally {
      pkg_ffi.calloc.free(geopos);
      pkg_ffi.calloc.free(tret);
      pkg_ffi.calloc.free(serr);
      pkg_ffi.calloc.free(starname);
    }
  }
```

- [ ] **Step 2: Add a basic test**

Add to `test/calc_test.dart`:

```dart
  group('riseTrans', () {
    test('sunrise at Washington DC on J2000', () {
      final jd = swe.julday(2000, 1, 1, 0.0);
      final result = swe.riseTrans(
        jd,
        seSun,
        rsmi: seCalcRise,
        geolon: -77.0365,
        geolat: 38.8977,
      );
      // Sunrise should be between 0:00 and 24:00 UT on that day
      // (jd is midnight UT, sunrise ~12:23 UT = ~7:23 EST)
      expect(result.transitTime, greaterThan(jd));
      expect(result.transitTime, lessThan(jd + 1));
    });
  });
```

- [ ] **Step 3: Run all tests**

```bash
dart test -v
```

Expected: All pass.

- [ ] **Step 4: Commit**

```bash
git add lib/src/swiss_eph.dart test/calc_test.dart
git commit -m "feat: add riseTrans for sunrise/set/transit calculations"
```

---

### Task 13: Isolate Safety Test

**Files:**
- Create: `test/isolate_test.dart`

**Context:** This is the critical test that proves swisseph.dart is isolate-safe. Two isolates with different sidereal modes must produce different results without cross-contamination. This requires loading separate .so copies (because dlopen deduplicates by inode).

**Key insight from the sweph.dart spike:** Dart isolates sharing the same .so path will share C global state. Each isolate must load from a unique file path.

- [ ] **Step 1: Write the isolate test**

Create `test/isolate_test.dart`:

```dart
import 'dart:io';
import 'dart:isolate';
import 'package:test/test.dart';
import 'package:swisseph/swisseph.dart';

/// Find the built .so path.
String _findLibrary() {
  final candidates = Directory('.dart_tool')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('libswisseph.so') ||
                     f.path.endsWith('libswisseph.dylib'))
      .map((f) => f.path)
      .toList();
  if (candidates.isEmpty) {
    throw StateError('libswisseph not found in .dart_tool/');
  }
  return candidates.first;
}

/// Copy the .so to a unique path for isolate safety.
String _copyLibForIsolate(String sourcePath, int id) {
  final tmpDir = Directory.systemTemp.createTempSync('swisseph_isolate_');
  final destPath = '${tmpDir.path}/libswisseph_$id.so';
  File(sourcePath).copySync(destPath);
  return destPath;
}

/// Compute Sun longitude with a specific sidereal mode in an isolate.
Future<double> _calcInIsolate(String libPath, int sidMode) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(
    (args) {
      final (String path, int mode, SendPort port) = args;
      final swe = SwissEph(path);
      swe.setSidMode(mode);
      final jd = swe.julday(2000, 1, 1, 0.0);
      final result =
          swe.calcUt(jd, seSun, seFlgMosEph | seFlgSpeed | seFlgSidereal);
      swe.close();
      port.send(result.longitude);
    },
    (libPath, sidMode, receivePort.sendPort),
  );
  return await receivePort.first as double;
}

void main() {
  late String baseLibPath;

  setUpAll(() {
    baseLibPath = _findLibrary();
  });

  group('isolate safety', () {
    test('different sidereal modes produce different results in parallel', () async {
      // Create unique .so copies
      final lahiriPath = _copyLibForIsolate(baseLibPath, 1);
      final ramanPath = _copyLibForIsolate(baseLibPath, 2);

      try {
        // Run in parallel with different ayanamsas
        final results = await Future.wait([
          _calcInIsolate(lahiriPath, seSidmLahiri),
          _calcInIsolate(ramanPath, seSidmRaman),
        ]);

        final lahiriSun = results[0];
        final ramanSun = results[1];

        // Lahiri and Raman ayanamsas differ by ~1°, so sidereal positions must differ
        expect((lahiriSun - ramanSun).abs(), greaterThan(0.5),
            reason: 'Lahiri and Raman should give different sidereal longitudes');
      } finally {
        File(lahiriPath).deleteSync();
        File(ramanPath).deleteSync();
      }
    });

    test('shared .so path causes state contamination', () async {
      // This test documents the PROBLEM: same .so path = shared global state.
      // Both isolates see whatever setSidMode was called last.
      // This is expected behavior — the workaround is unique .so copies.
      final sharedPath = _copyLibForIsolate(baseLibPath, 99);

      try {
        // Both use same path — they'll share C state
        final results = await Future.wait([
          _calcInIsolate(sharedPath, seSidmLahiri),
          _calcInIsolate(sharedPath, seSidmRaman),
        ]);

        // With shared state, results MAY be identical (race condition)
        // or MAY differ depending on timing. This test just documents the risk.
        // The point is: DON'T use shared paths for concurrent isolates.
        // We just verify both returned valid values.
        expect(results[0], greaterThan(0));
        expect(results[1], greaterThan(0));
      } finally {
        File(sharedPath).deleteSync();
      }
    });
  });
}
```

- [ ] **Step 2: Run the isolate test**

```bash
dart test test/isolate_test.dart -v
```

Expected: Both tests pass. The first test proves isolate safety with unique .so copies. The second documents the contamination risk with shared paths.

- [ ] **Step 3: Commit**

```bash
git add test/isolate_test.dart
git commit -m "test: add isolate safety proof (unique .so copies prevent state contamination)"
```

---

### Task 14: Example + Barrel Polish

**Files:**
- Create: `example/example.dart`
- Modify: `lib/swisseph.dart` (verify exports)

- [ ] **Step 1: Create example**

Create `example/example.dart`:

```dart
import 'package:swisseph/swisseph.dart';

void main() {
  final swe = SwissEph.find();

  print('Swiss Ephemeris v${swe.version()}');
  print('');

  // Calculate Sun and Moon positions for 2000-01-01 12:00 UT
  final jd = swe.julday(2000, 1, 1, 12.0);
  print('Julian Day: $jd (J2000.0 epoch)');
  print('');

  // Tropical positions
  final sun = swe.calcUt(jd, seSun, seFlgSwiEph | seFlgSpeed);
  final moon = swe.calcUt(jd, seMoon, seFlgSwiEph | seFlgSpeed);
  print('Tropical positions:');
  print('  ${swe.getPlanetName(seSun)}: ${sun.longitude.toStringAsFixed(4)}°'
      ' (speed: ${sun.longitudeSpeed.toStringAsFixed(4)}°/day)');
  print('  ${swe.getPlanetName(seMoon)}: ${moon.longitude.toStringAsFixed(4)}°'
      ' (speed: ${moon.longitudeSpeed.toStringAsFixed(4)}°/day)');
  print('');

  // Sidereal (Lahiri) positions
  swe.setSidMode(seSidmLahiri);
  final aya = swe.getAyanamsaUt(jd);
  final sidSun = swe.calcUt(jd, seSun, seFlgSwiEph | seFlgSpeed | seFlgSidereal);
  print('Lahiri ayanamsa: ${aya.toStringAsFixed(4)}°');
  print('Sidereal Sun: ${sidSun.longitude.toStringAsFixed(4)}°');
  print('');

  // House cusps (Campanus, Washington DC)
  final houses = swe.houses(jd, 38.8977, -77.0365, hsysCampanus);
  print('Campanus houses (Washington DC):');
  for (var i = 1; i <= 12; i++) {
    print('  House $i: ${houses.cusps[i].toStringAsFixed(4)}°');
  }
  print('  Ascendant: ${houses.ascendant.toStringAsFixed(4)}°');
  print('  MC: ${houses.mc.toStringAsFixed(4)}°');

  swe.close();
}
```

- [ ] **Step 2: Verify barrel exports are complete**

Ensure `lib/swisseph.dart` exports everything:

```dart
/// Isolate-safe Dart FFI bindings to the Swiss Ephemeris C library.
library swisseph;

export 'src/swiss_eph.dart';
export 'src/constants.dart';
export 'src/types.dart';
```

- [ ] **Step 3: Run the example**

```bash
dart run example/example.dart
```

Expected: Prints version, planet positions, ayanamsa, and house cusps.

- [ ] **Step 4: Run all tests one final time**

```bash
dart test -v
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add example/example.dart lib/swisseph.dart
git commit -m "feat: add usage example and polish barrel exports"
```

---

## Summary

After completing all 14 tasks, swisseph.dart will have:

- **16 bound functions:** swe_calc_ut, swe_houses, swe_set_sid_mode, swe_set_ephe_path, swe_set_topo, swe_close, swe_version, swe_julday, swe_revjul, swe_get_ayanamsa_ut, swe_get_ayanamsa_ex_ut, swe_get_ayanamsa_name, swe_get_planet_name, swe_house_name, swe_rise_trans, swe_degnorm
- **Instance-based design** for isolate safety
- **Native asset build hook** that compiles the C source automatically
- **Comprehensive tests** including isolate safety proof
- **Working example** demonstrating the full API

To add more functions later: add the `late final` lookup in `bindings.dart`, add the public method in `swiss_eph.dart`, write a test.
