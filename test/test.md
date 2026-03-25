# swisseph.dart test suite

55 tests across 7 files. All use the Moshier analytical ephemeris (no data files needed).

```
dart test test/date_test.dart test/calc_test.dart test/ayanamsa_test.dart \
         test/houses_test.dart test/isolate_test.dart \
         test/libaditya-validation/cross_validation_test.dart \
         test/swetest-validation/cross_validation_test.dart
```

## Overview

| File | Tests | What it covers |
|------|------:|----------------|
| date_test.dart | 11 | julday, revjul, planet/house names, degnorm, version |
| calc_test.dart | 5 | calcUt (tropical), riseTrans, error handling |
| ayanamsa_test.dart | 4 | Lahiri ayanamsa, sidereal position identity, getAyanamsaExUt |
| houses_test.dart | 4 | Campanus cusps, Whole Sign 30-degree spacing, result structure |
| isolate_test.dart | 2 | Unique .so copies prevent state contamination across isolates |
| libaditya cross-validation | 14 | 545 reference values from pyswisseph |
| swetest cross-validation | 15 | ~504 reference values from swetest CLI |

---

## Unit tests

### date_test.dart (11 tests)

**version**
- `version()` returns a non-empty string containing '.'

**julday**
- J2000.0 epoch: `julday(2000, 1, 1, 12.0)` = 2451545.0 exactly
- Known date: `julday(1985, 1, 1, 0.0)` = 2446066.5 exactly

**revjul**
- J2000.0 roundtrip: `revjul(2451545.0)` returns 2000-01-01 12:00 (hour tolerance 1e-10)
- julday/revjul roundtrip: 1990-06-15 18:30 survives julday -> revjul (hour tolerance 1e-6)

**names**
- `getPlanetName(seSun)` = "Sun"
- `getPlanetName(seMoon)` = "Moon"
- `houseName(hsysCampanus)` contains "campanus" (case-insensitive)

**degnorm**
- Negative degrees: `degnorm(-10.0)` = 350.0
- Overflow: `degnorm(370.0)` = 10.0
- Passthrough: `degnorm(180.0)` = 180.0

### calc_test.dart (5 tests)

**calcUt**
- Sun at J2000 midnight (Moshier): longitude ~279.858, speed ~1.019 (tolerance 0.01)
- Moon at J2000 midnight (Moshier): longitude ~217.284, speed ~12.103 (tolerance 0.01)
- All 7 classical planets return valid longitudes in [0, 360) with positive returnFlag
- Invalid body (-2) throws `SweException`

**riseTrans**
- Sunrise at Washington DC on J2000: transit time is between jd and jd+1

### ayanamsa_test.dart (4 tests)

- Lahiri ayanamsa at J2000: `getAyanamsaUt()` ~23.853 (tolerance 0.01)
- `getAyanamsaName(seSidmLahiri)` contains "lahiri" (case-insensitive)
- Sidereal identity: sidereal longitude = (tropical - ayanamsa) mod 360 (tolerance 0.01)
- `getAyanamsaExUt(jd, seFlgMosEph)` returns consistent values across repeated calls, ~23.853

### houses_test.dart (4 tests)

- Campanus at J2000 noon, Washington DC: cusps 1/4/7/10 and ascendant/MC/ARMC/vertex match expected values (tolerance 0.001)
- Whole Sign houses: each cusp is exactly 30 degrees apart starting from ascendant's sign boundary
- `cusps` list has 13 elements (index 0 unused, C convention)
- `ascmc` list has 10 elements

### isolate_test.dart (2 tests)

Both tests create temporary copies of `libswisseph.so` (found in `.dart_tool/`) to test isolate behaviour.

- **Unique .so copies**: two isolates with different sidereal modes (Lahiri, Raman) on separate .so copies produce results differing by >0.5 degrees — proves isolation works
- **Shared .so path**: two isolates sharing one .so copy both return valid values, but global state is shared (documents the race condition that unique copies solve)

---

## Cross-validation suites

Two independent cross-validation suites verify the Dart FFI bindings produce identical results to other Swiss Ephemeris implementations.

### libaditya cross-validation (14 tests, 545 reference values)

**Reference source**: pyswisseph (Python ctypes FFI to the same C library)
**Reference file**: `test/libaditya-validation/reference_data.json`
**Base tolerance**: 1e-8 (same C library, only marshalling differs)

| Test group | Count | What's compared | Tolerance |
|------------|------:|-----------------|-----------|
| Julian Day conversion | 7 | `julday` for 7 dates (J2000, historical, future) | 1e-8 |
| Julian Day roundtrip | 7 | `revjul` year/month/day exact, hour | 1e-6 |
| Planet positions (tropical) | 91 | lon/lat/dist/speeds for 13 bodies x 7 dates | 1e-8 |
| Sidereal positions | 56 | sidereal lon/lat for Sun+Moon x 14 ayanamsas x 2 dates | 1e-8 |
| Ayanamsa values | 98 | 14 ayanamsas x 7 dates | 1e-8 (1e-4 for star-based) |
| Ayanamsa names | 14 | string match for 14 ayanamsas | exact |
| House cusps | 154 | 12 cusps + 8 ascmc for 11 systems x 7 locations x 2 dates | 1e-8 |
| House system names | 11 | string match | exact |
| Planet names | 13 | string match for 13 bodies | exact |
| Rise/set times | ~32 | rise+set for Sun+Moon x 4 locations x 2 dates | 1e-4 |
| Degree normalization | 15 | negative, >360, edge cases | 1e-8 |
| Topocentric positions | 8 | Sun+Moon x 4 locations with TOPOCTR flag | 1e-8 |
| Equatorial coordinates | 7 | RA/Dec for 7 classical planets with EQUATORIAL flag | 1e-8 |
| Coverage summary | 1 | validates reference data section counts | exact |

### swetest cross-validation (15 tests, ~504 reference values)

**Reference source**: swetest (official C test binary from Swiss Ephemeris)
**Reference file**: `test/swetest-validation/reference_data.json`
**Generator**: `test/swetest-validation/generate_reference.dart`
**Base tolerance**: 1e-7 (swetest text output truncates to ~7 decimal places)

| Test group | Count | What's compared | Tolerance |
|------------|------:|-----------------|-----------|
| Julian Day conversion | 7 | `julday` for 7 dates | 1e-7 |
| Julian Day roundtrip | 7 | `revjul` year/month/day exact, hour | 1e-6 |
| Planet positions (tropical) | 91 | lon/lat/dist/speeds for 13 bodies x 7 dates | 1e-7 |
| Sidereal positions | 56 | sidereal lon/lat for Sun+Moon x 14 ayanamsas x 2 dates | 1e-7 |
| Ayanamsa values | 98 | `getAyanamsaExUt` with MOSEPH flag, 14 ayanamsas x 7 dates | 1e-7 (1e-4 for star-based) |
| Ayanamsa names | 14 | string match | exact |
| House cusps | 154 | 12 cusps + 8 ascmc for 11 systems x 7 locations x 2 dates | 1e-7 |
| House system names | 11 | string match | exact |
| Planet names | 13 | string match | exact |
| Rise/set times | ~26 | rise+set for Sun+Moon x 4 locations x 2 dates | 1e-3 |
| Degree normalization | 15 | negative, >360, edge cases | 1e-7 |
| Topocentric positions | 8 | Sun+Moon x 4 locations with TOPOCTR flag | 1e-7 |
| Equatorial coordinates | 7 | RA/Dec for 7 classical planets with EQUATORIAL flag | 1e-4 |
| getAyanamsaExUt | 4 | `getAyanamsaExUt` with flag parameter | 1e-7 (1e-4 for star-based) |
| Coverage summary | 1 | validates reference data section counts | exact |

**Key difference from libaditya**: swetest reference uses text parsing which limits precision. The ayanamsa test uses `getAyanamsaExUt(jd, seFlgMosEph)` instead of `getAyanamsaUt(jd)` to match swetest's `-emos` (Moshier) mode — these two functions use different internal ephemeris paths and differ by ~0.004 degrees.

---

## Test parameters

### Bodies (13)
Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune, Pluto, mean Node, true Node, Chiron

### House systems (11)
Placidus, Koch, Porphyry, Regiomontanus, Campanus, Equal, Whole Sign, Alcabitius, Topocentric (Polich-Page), Meridian, Morinus

### Ayanamsas (14)
Fagan-Bradley, Lahiri, Raman, Krishnamurti, Yukteshwar, JN Bhasin, DeLuce, Aryabhata, True Citra, True Revati, True Pushya, GalCent Mula Wilhelm, Hipparchos, Sassanian

### Locations (7)
Washington DC, New Delhi, London, Sydney, Null Island (0,0), Reykjavik (high latitude), Ushuaia (far south)

### Dates (7)
J2000.0 midnight, J2000.0 noon, 1985-01-01, 1990-06-15 18:30, 2024-03-20 (vernal equinox), 1947-08-15 (historical), 2050-12-31 23:59

## API coverage

All 15 public methods of `SwissEph` are tested:

| Method | Tested in |
|--------|-----------|
| `julday` | date_test, both cross-validations |
| `revjul` | date_test, both cross-validations |
| `calcUt` | calc_test, both cross-validations (tropical, sidereal, topocentric, equatorial) |
| `houses` | houses_test, both cross-validations |
| `getAyanamsaUt` | ayanamsa_test, libaditya cross-validation |
| `getAyanamsaExUt` | ayanamsa_test, swetest cross-validation |
| `getAyanamsaName` | ayanamsa_test, both cross-validations |
| `getPlanetName` | date_test, both cross-validations |
| `houseName` | date_test, both cross-validations |
| `riseTrans` | calc_test, both cross-validations |
| `degnorm` | date_test, both cross-validations |
| `setSidMode` | used by sidereal/ayanamsa tests |
| `setTopo` | used by topocentric tests |
| `setEphePath` | implicitly tested (Moshier = no path needed) |
| `close` | called in tearDownAll |
| `version` | date_test |
