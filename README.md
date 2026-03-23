# swisseph

Dart FFI bindings to the [Swiss Ephemeris](https://www.astro.com/swisseph/)
C library.

Compute planetary positions, house cusps, ayanamsa values, and rise/set
times — with no code generation, no Flutter dependency, and full isolate
safety.

## Features

- **15 methods** covering positions, houses, ayanamsa, rise/set, date
  conversion, and configuration
- **All 47 standard ayanamsas** — Lahiri, Fagan-Bradley, Raman,
  Krishnamurti, and 43 more
- **11 house systems** — Placidus, Koch, Whole Sign, Campanus, Equal,
  and more
- **Three ephemeris engines** — Moshier (no files needed), Swiss
  Ephemeris (.se1 files), JPL
- **Multiple coordinate systems** — tropical, sidereal, heliocentric,
  barycentric, equatorial
- **Isolate-safe** — each instance wraps its own `DynamicLibrary`; copy
  the `.so` per isolate for independent C global state
- **Instance-based API** — no singletons, no hidden state
- **Native asset build hook** — `dart pub get` compiles the vendored C
  source automatically via `CBuilder`

## Platform support

| Platform | Status                |
|----------|-----------------------|
| Linux    | Supported (gcc/clang) |
| macOS    | Supported (clang)     |
| Windows  | Supported (MSVC)      |

Requires Dart SDK 3.11+ and a C compiler.

## Install

```bash
dart pub add swisseph
```

Or add it to your `pubspec.yaml` directly:

```yaml
dependencies:
  swisseph: ^0.1.0
```

Alternatively, install from the Git repository:

```yaml
dependencies:
  swisseph:
    git:
      url: https://gitlab.com/ninthhouse/swisseph.dart
      ref: master
```

Then run `dart pub get`, which triggers the native build hook to compile
the C source.

## Quick start

```dart
import 'package:swisseph/swisseph.dart';

void main() {
  final swe = SwissEph.find();

  // Julian Day for 2000-01-01 12:00 UT
  final jd = swe.julday(2000, 1, 1, 12.0);

  // Sun position (Moshier — no data files needed)
  final sun = swe.calcUt(jd, seSun, seflgMoseph | seflgSpeed);
  print('Sun: ${sun.longitude}°');

  // Sidereal position (Lahiri)
  swe.setSidMode(seSidmLahiri);
  final sidSun = swe.calcUt(
    jd, seSun, seflgMoseph | seflgSpeed | seflgSidereal,
  );
  print('Sidereal Sun: ${sidSun.longitude}°');

  // House cusps (Campanus, Washington DC)
  final houses = swe.houses(jd, 38.8977, -77.0365, hsysCampanus);
  print('Ascendant: ${houses.ascendant}°');
  print('MC: ${houses.mc}°');

  // Sunrise
  final rise = swe.riseTrans(
    jd, seSun,
    rsmi: seCalcRise, geolon: -77.0365, geolat: 38.8977,
  );
  print('Sunrise JD: ${rise.transitTime}');

  swe.close();
}
```

See [`example/example.dart`](example/example.dart) for a fuller example
with formatted output.

## API reference

| Category  | Methods                                                      |
|-----------|--------------------------------------------------------------|
| Date/time | `julday`, `revjul`                                           |
| Config    | `setEphePath`, `setSidMode`, `setTopo`, `close`, `version`   |
| Positions | `calcUt`                                                     |
| Houses    | `houses`                                                     |
| Ayanamsa  | `getAyanamsaUt`, `getAyanamsaExUt`, `getAyanamsaName`        |
| Names     | `getPlanetName`, `houseName`                                 |
| Rise/set  | `riseTrans`                                                  |
| Utilities | `degnorm`                                                    |

All native memory uses `calloc` + `try/finally free`. Errors throw
`SweException`.

## Ephemeris modes

| Mode            | Flag           | Files needed        | Accuracy       |
|-----------------|----------------|---------------------|----------------|
| Moshier         | `seflgMoseph`  | None                | ~1 arcsecond   |
| Swiss Ephemeris | `seflgSwieph`  | `.se1` data files   | Sub-arcsecond  |
| JPL             | `seflgJpleph`  | JPL ephemeris files | Highest        |

Moshier is a good default — it works out of the box with no data files.

For higher precision, download `.se1` files from
[astro.com/ftp/swisseph/ephe](https://www.astro.com/ftp/swisseph/ephe/)
into an `ephe/` directory alongside your project, then point to them:

```dart
swe.setEphePath('ephe');
final sun = swe.calcUt(jd, seSun, seflgSwieph | seflgSpeed);
```

The ephemeris data files are not included in this package — you download
them separately as needed. The three file sets are:

- `sepl_*.se1` — main planets
- `semo_*.se1` — Moon
- `seas_*.se1` — asteroids (Chiron, Ceres, etc.)

Each file covers 600 years. Download the ranges you need.

## Constants

Integer constants, not enums. Defined in `lib/src/constants.dart`.

| Prefix   | Purpose           | Example           |
|----------|-------------------|-------------------|
| `se`     | Body IDs          | `seSun`, `seMoon` |
| `seflg`  | Calculation flags | `seflgSpeed`      |
| `hsys`   | House systems     | `hsysPlacidus`    |
| `seSidm` | Ayanamsa modes    | `seSidmLahiri`    |
| `seCalc` | Rise/set flags    | `seCalcRise`      |

## Isolate safety

`dlopen` deduplicates shared libraries by device+inode. Two isolates
loading the same `.so` path share C global state — sidereal mode,
ephemeris path, and topocentric coordinates all leak between them.

The fix: copy the `.so` to a unique temp path per isolate. Each copy
gets its own C globals.

```dart
// Copy the .so for this isolate
final tmpDir = Directory.systemTemp.createTempSync('swe_');
final libPath = '${tmpDir.path}/libswisseph_$id.so';
File(sharedLibPath).copySync(libPath);

final swe = SwissEph(libPath);
```

See [`test/isolate_test.dart`](test/isolate_test.dart) for the full
pattern. The [stress test](test/stress-test.md) runs 3.06 billion
calculations across 100 isolates to prove this holds at scale.

## Limitations

- **No Flutter plugin** — this is a pure Dart package using native asset
  build hooks. Works with Dart CLI and can be used from Flutter, but is
  not a Flutter plugin.
- **No asteroid files** — only the bodies built into the Swiss Ephemeris
  core (Sun through Chiron, nodes, apogees) are exposed. Numbered
  asteroids via `seAstOffset` require additional `.se1` files and are
  untested.
- **C global state** — the underlying C library uses global state. See
  [Isolate safety](#isolate-safety) above.

## Tests

```bash
dart test
```

- 26 unit tests across date, calc, houses, ayanamsa, and isolate safety
- 545-value cross-validation suite against
  [pyswisseph](https://gitlab.com/ninthhouse/libaditya) covering
  13 bodies, 14 ayanamsas, 11 house systems, 7 locations, 7 dates
- Stress test: 3.06 billion calculations across 100 isolates (Moshier +
  Swiss Ephemeris, all 47 ayanamsas, heliocentric, barycentric,
  equatorial). See [`test/stress-test.md`](test/stress-test.md).

## License

This Dart package is licensed under [AGPL-3.0-or-later](LICENSE).

The Swiss Ephemeris C library (vendored in `csrc/`) is copyright
Astrodienst AG and dual-licensed under AGPL-3.0 and a commercial
license. See [astro.com/swisseph](https://www.astro.com/swisseph/) for
commercial licensing details.

## Issues and contributions

File issues and merge requests on
[GitLab](https://gitlab.com/ninthhouse/swisseph.dart).
