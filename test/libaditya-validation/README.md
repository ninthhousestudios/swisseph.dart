# Cross-validation: swisseph.dart vs pyswisseph (libaditya)

Cross-library validation tests that verify swisseph.dart's Dart FFI bindings
produce identical results to pyswisseph (the Python bindings used by
[libaditya](https://gitlab.com/ninthhouse/libaditya)). Both libraries call the
same Swiss Ephemeris C code, so results should match to floating-point
precision.

## How it works

```
pyswisseph (Python)          swisseph.dart (Dart FFI)
        │                            │
        ▼                            ▼
  generate_reference.py        cross_validation_test.dart
        │                            │
        ▼                            ▼
  reference_data.json ──────▶  load & compare
  (545 values)                 (14 test groups)
```

1. **`generate_reference.py`** calls pyswisseph to compute 545 reference values
   across all function categories and writes them to `reference_data.json`.
2. **`cross_validation_test.dart`** loads that JSON and compares every value
   against the same computation via swisseph.dart.

## Running

### 1. Generate reference data (once, or when pyswisseph updates)

Requires a [libaditya](https://gitlab.com/ninthhouse/libaditya) checkout with
its Python environment set up (`uv venv && uv add . --dev`).

```bash
cd <libaditya-checkout>
uv run python <swisseph.dart>/test/libaditya-validation/generate_reference.py
```

### 2. Run the Dart tests

```bash
cd <swisseph.dart>
dart test test/libaditya-validation/cross_validation_test.dart
```

## What's tested

### 545 reference values across 14 test groups

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
| Rise/set times | 32 | `riseTrans` rise+set for Sun+Moon × 4 locations × 2 dates |
| Degree normalization | 15 | `degnorm` for negative, >360, edge cases |
| Topocentric positions | 8 | `calcUt` with `TOPOCTR` for Sun+Moon × 4 locations |
| Equatorial coordinates | 7 | `calcUt` with `EQUATORIAL` RA/Dec for 7 classical planets |
| Coverage summary | 1 | Validates reference data section counts |

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
| Star-based ayanamsas | 1e-4 | True Citra/Revati/Pushya/Mula and GalCent use fixed star positions that depend on which ephemeris engine (Moshier vs SE files) was last loaded |
| Rise/set times | 1e-4 | Iterative solver; minor floating-point path differences |

## Notes

- **Ephemeris mode**: Reference data was generated with pyswisseph using the
  Swiss Ephemeris `.se1` files bundled with libaditya. The Dart tests use
  Moshier mode (no files). For tropical/sidereal calculations, Moshier and
  Swiss Ephemeris agree to ~1 arcsecond. For `getAyanamsaUt`, the "True"
  ayanamsas (which use fixed star positions internally) show ~0.00003°
  differences between engines.

- **House cusp indexing**: pyswisseph returns 12 cusps (0-indexed); swisseph.dart
  returns 13 (index 0 unused, matching the C convention). The test accounts for
  this offset.

- **ascmc array size**: pyswisseph returns 8 ascmc values; swisseph.dart returns
  10. The test compares the first 8.
