# swisseph.dart

Dart FFI bindings to the [Swiss Ephemeris](https://www.astro.com/swisseph/) C library — planetary positions, house cusps, ayanamsa, rise/set times.

Instance-based, isolate-safe, no code generation. Uses Dart 3.11+ native asset build hooks to compile the C source automatically.

## Requirements

- Dart SDK 3.11+
- [Swiss Ephemeris C source](https://github.com/aloistr/swisseph) (clone as `swisseph/` next to `swisseph.dart/`, or set `SWISSEPH_SRC`)
- C compiler (gcc/clang)

## Install

```yaml
# pubspec.yaml
dependencies:
  swisseph:
    git:
      url: https://gitlab.com/ninthhouse/swisseph.dart
```

```bash
dart pub get   # triggers native build hook
```

## Usage

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
  final sidSun = swe.calcUt(jd, seSun, seflgMoseph | seflgSpeed | seflgSidereal);
  print('Sidereal Sun: ${sidSun.longitude}°');

  // House cusps (Campanus, Washington DC)
  final houses = swe.houses(jd, 38.8977, -77.0365, hsysCampanus);
  print('Ascendant: ${houses.ascendant}°');
  print('MC: ${houses.mc}°');

  // Sunrise
  final rise = swe.riseTrans(jd, seSun, rsmi: seCalcRise, geolon: -77.0365, geolat: 38.8977);
  print('Sunrise JD: ${rise.transitTime}');

  swe.close();
}
```

## Available functions

| Category | Methods |
|----------|---------|
| Date/time | `julday`, `revjul` |
| Config | `setEphePath`, `setSidMode`, `setTopo`, `close`, `version` |
| Positions | `calcUt` |
| Houses | `houses` |
| Ayanamsa | `getAyanamsaUt`, `getAyanamsaExUt`, `getAyanamsaName` |
| Names | `getPlanetName`, `houseName` |
| Rise/set | `riseTrans` |
| Utilities | `degnorm` |

## Ephemeris modes

- **Moshier** (`seflgMoseph`): Analytical, no data files, ~1 arcsecond accuracy. Good default.
- **Swiss Ephemeris** (`seflgSwieph`): Requires `.se1` data files via `setEphePath()`. Sub-arcsecond.
- **JPL** (`seflgJpleph`): Requires JPL ephemeris files. Highest precision.

## Isolate safety

Each `SwissEph` instance wraps its own `DynamicLibrary`. However, `dlopen` deduplicates by inode — to get independent state in isolates, copy the `.so` to a unique temp path per isolate. See `test/isolate_test.dart` for the pattern.

## Tests

```bash
dart test
```

Includes 26 unit tests plus a 545-value cross-validation suite against
[libaditya](https://gitlab.com/ninthhouse/libaditya) (pyswisseph). See
`test/libaditya-validation/` for details.

## License

The Swiss Ephemeris library is dual-licensed (GPL/commercial). See [astro.com/swisseph](https://www.astro.com/swisseph/) for details.
