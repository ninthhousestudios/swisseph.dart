# Cross-validation: swisseph.dart vs swetest

Cross-library validation tests that verify swisseph.dart's Dart FFI bindings
produce identical results to [swetest](https://www.astro.com/swisseph/), the
official test program distributed with the Swiss Ephemeris C library. Both use
the Moshier analytical ephemeris (no data files needed), so results should match
to floating-point precision.

## How it works

```
swetest (C binary)               swisseph.dart (Dart FFI)
        │                                │
        ▼                                ▼
  generate_reference.dart          cross_validation_test.dart
        │                                │
        ▼                                ▼
  reference_data.json ──────────▶  load & compare
  (~550 values)                    (15 test groups)
```

1. **`generate_reference.dart`** calls the swetest binary to compute ~550
   reference values across all function categories and writes them to
   `reference_data.json`.
2. **`cross_validation_test.dart`** loads that JSON and compares every value
   against the same computation via swisseph.dart.

## Running

### 1. Build swetest (once)

```bash
cd ../../swisseph
make swetest
```

### 2. Generate reference data (once, or when Swiss Ephemeris updates)

```bash
cd <swisseph.dart>
dart run test/swetest-validation/generate_reference.dart [swetest_path]
```

Default swetest path: `../../swisseph/bin/swetest`

### 3. Run the Dart tests

```bash
cd <swisseph.dart>
dart test test/swetest-validation/cross_validation_test.dart
```

## What's tested

### ~550 reference values across 15 test groups

| Test group | Count | What's compared |
|------------|------:|-----------------|
| Julian Day conversion | 7 | `julday` date→JD for 7 dates (J2000, historical, future) |
| Julian Day roundtrip | 7 | `revjul` JD→date year/month/day/hour |
| Planet positions (Moshier) | 91 | `calcUt` tropical lon/lat/dist/speeds for 13 bodies × 7 dates |
| Sidereal positions | 56 | `calcUt` sidereal lon/lat for Sun+Moon × 14 ayanamsas × 2 dates |
| Ayanamsa values | 98 | `getAyanamsaUt` for 14 ayanamsas × 7 dates |
| Ayanamsa names | 14 | `getAyanamsaName` for 14 sidereal modes |
| House cusps | 154 | `houses` 12 cusps + 8 ascmc for 11 systems × 7 locations × 2 dates |
| House system names | 11 | `houseName` for all 11 systems |
| Planet names | 13 | `getPlanetName` for all 13 bodies |
| Rise/set times | ~32 | `riseTrans` rise+set for Sun+Moon × 4 locations × 2 dates |
| Degree normalization | 15 | `degnorm` for negative, >360, edge cases |
| Topocentric positions | 8 | `calcUt` with `TOPOCTR` for Sun+Moon × 4 locations |
| Equatorial coordinates | 7 | `calcUt` with `EQUATORIAL` RA/Dec for 7 classical planets |
| getAyanamsaExUt | 4 | `getAyanamsaExUt` with flag parameter for representative cases |
| Coverage summary | 1 | Validates reference data section counts |

### Functions covered

All 15 public methods of SwissEph are validated:

| Method | Test group(s) |
|--------|--------------|
| `julday` | Julian Day conversion |
| `revjul` | Julian Day roundtrip |
| `calcUt` | Planet positions, Sidereal, Topocentric, Equatorial |
| `houses` | House cusps |
| `getAyanamsaUt` | Ayanamsa values |
| `getAyanamsaExUt` | getAyanamsaExUt |
| `getAyanamsaName` | Ayanamsa names |
| `getPlanetName` | Planet names |
| `houseName` | House system names |
| `riseTrans` | Rise/set times |
| `degnorm` | Degree normalization |
| `setSidMode` | Used by Sidereal, Ayanamsa tests |
| `setTopo` | Used by Topocentric tests |
| `setEphePath` | Implicitly tested (Moshier = no path needed) |
| `close` | Called in tearDownAll |
| `version` | Not compared (different binary versions possible) |

### Bodies tested

Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune, Pluto,
Mean Node, True Node, Chiron.

### House systems tested

Placidus, Koch, Porphyry, Regiomontanus, Campanus, Equal, Whole Sign,
Alcabitius, Topocentric (Polich-Page), Meridian, Morinus.

### Ayanamsas tested

Fagan-Bradley, Lahiri, Raman, Krishnamurti, Yukteshwar, JN Bhasin, DeLuce,
Aryabhata, True Citra, True Revati, True Pushya, GalCent Mula Wilhelm,
Hipparchos, Sassanian.

### Locations tested

Washington DC, New Delhi, London, Sydney, Null Island (0°,0°), Reykjavik
(high latitude), Ushuaia (far south).

### Dates tested

J2000.0 midnight, J2000.0 noon, 1985-01-01, 1990-06-15 18:30, 2024-03-20
(vernal equinox), 1947-08-15 (historical), 2050-12-31 23:59.

## Tolerances

| Category | Tolerance | Reason |
|----------|-----------|--------|
| Most values | 1e-8 | Same C library; only double marshalling differs |
| Star-based ayanamsas | 1e-4 | True Citra/Revati/Pushya/Mula and GalCent use fixed star positions |
| Rise/set times | 1e-3 | swetest outputs HH:MM:SS.S (~0.1s precision); JD reconstructed from text |
| Equatorial coords | 1e-4 | swetest -fa format vs swe_calc_ut EQUATORIAL flag conversion paths |

## Comparison with libaditya-validation

Both test suites validate the same swisseph.dart API surface. They differ in the
reference source:

| | libaditya-validation | swetest-validation |
|--|---------------------|-------------------|
| Reference source | pyswisseph (Python FFI) | swetest (C binary) |
| Reference format | Python script | Dart script calling swetest CLI |
| Ephemeris in reference | Swiss Ephemeris .se1 files | Moshier (no files) |
| Ephemeris in Dart test | Moshier | Moshier |
| Extra coverage | — | `getAyanamsaExUt` |

Having two independent reference sources provides stronger validation:
pyswisseph goes through Python ctypes, swetest goes through C `main()` → both
should agree with Dart FFI.
