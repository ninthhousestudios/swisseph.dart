# Stress Test 0.2 — Full API Coverage

`test/stress-test-0.2/stress_test_0_2.dart`

## Results (2026-03-25)

| Metric | Value |
|--------|-------|
| Isolates | 100 (pool of 20 concurrent) |
| Total calculations | 4.11 billion |
| Wall time | 125m 37s |
| Throughput | 545.2K calcs/sec |
| Fatal errors | 0 |
| Expected errors | 3,041,700 |

### Per-category breakdown

| Category | Calls |
|----------|------:|
| calcUt | 3.30B |
| calc (ET, every 5th date) | ~66M |
| houses (all 5 variants) | 129.3M |
| ayanamsa (5 methods × 52 modes) | 510.1M |
| dateTime | ~30M |
| positionExt | ~18M |
| fixedStar | ~10M |
| coordinate | ~10M |
| utility | ~18M |
| crossing | ~120K |
| riseSet | ~560K |
| eclipse | ~20K |
| heliacal | ~4.5K |
| gauquelin | ~45K |
| name + config | ~5K |

### Verification results

All six verification checks passed (the `setTopo` tracking bug in the
original run has been fixed):

1. **No fatal errors** — all 100 isolates completed successfully.
2. **Isolation (longitude)** — isolates sharing the same ayanamsa
   produced bit-identical Sun sidereal reference longitudes.
3. **Isolation (Ascendant)** — same ayanamsa produced identical
   sidereal Campanus Ascendant values at Delhi.
4. **Distinctness** — each of the 47 standard ayanamsas produced a
   unique reference longitude (no collisions).
5. **API coverage** — all 88 public methods exercised in every isolate.
6. **Error paths exercised** — 3,041,700 expected errors triggered
   (polar house failures, circumpolar rise/set, crossing search
   failures, heliacal failures).

### Environment

- Dart 3.11
- Linux 6.19.6-arch1-1, x86_64
- Moshier + Swiss Ephemeris (.se1 files in `ephe/`)
- Single machine, no network

## What it does

Spawns 100 Dart isolates (batched through a pool of 20 concurrent workers) and
hammers **every public method** in the Swiss Ephemeris Dart binding — all 88
methods across 13 API categories — with billions of calculations across 5,000
years of quarterly dates, 14 celestial bodies, 47 standard ayanamsas + 5
user-defined ayanamsas, 8 geographic locations (including one polar), 11 house
systems, two ephemeris engines, 10 coordinate modes, 10 fixed stars, eclipse
searches, crossing searches, rise/set computations, heliacal phenomena, and
Gauquelin sectors.

Each isolate gets its own copy of the compiled `.so` to guarantee true C-level
isolation. Between every workload module, global state is scrambled
(ayanamsa, topocentric origin, nutation interpolation) to maximize the window
for cross-isolate contamination.

After all isolates finish, the test verifies:

1. **No fatal errors** — every isolate completed successfully.
2. **Isolation (longitude)** — isolates assigned the same ayanamsa produced
   bit-identical Sun sidereal reference longitudes.
3. **Isolation (Ascendant)** — same ayanamsa → identical sidereal Campanus
   Ascendant at Delhi.
4. **Distinctness** — different ayanamsas produced different reference values.
5. **API coverage** — all 88 public methods appear in every isolate's
   `methodsCalled` checklist.
6. **Error paths exercised** — expected errors (polar house failures,
   circumpolar rise/set, crossing search failures) were actually triggered.

## Why it exists

Stress test 0.1 (`test/stress-test/`) proved isolate isolation scales for
`calcUt` + `houses`. But swisseph.dart v0.2 expanded from 15 to 88 public
methods. This test proves the full API works correctly under concurrent load —
not just the calculation engine, but every function category: date/time
conversions, configuration setters, fixed stars, eclipses, crossings, heliacal
events, coordinate transforms, and more.

The user-defined ayanamsa entries (`seSidmUser` with custom t0/ayanT0) test a
code path that standard ayanamsas don't: the `t0` and `ayanT0` parameters to
`setSidMode`, which set a custom reference epoch and ayanamsa value. These
exercise the C library's user-defined sidereal mode under concurrent global
state churn.

## API categories tested

| Category | Methods | Workload module |
|----------|---------|-----------------|
| Date/time | 15 | `_runDateTimeWorkload` |
| Config | 13 | `_runConfigWorkload` + `_scrambleState` |
| Positions | 8 | `_runCalcWorkload` + `_runPositionExtWorkload` |
| Fixed stars | 3 | `_runFixedStarWorkload` |
| Houses | 7 | `_runHouseWorkload` + `_runGauquelinWorkload` |
| Ayanamsa | 5 | `_runAyanamsaWorkload` |
| Eclipses | 10 | `_runEclipseWorkload` |
| Crossings | 8 | `_runCrossingWorkload` |
| Rise/set | 2 | `_runRiseSetWorkload` |
| Heliacal | 3 | `_runHeliacalWorkload` |
| Coordinates | 5 | `_runCoordinateWorkload` |
| Names | 2 | `_runNameWorkload` |
| Utilities | 7 | `_runUtilityWorkload` |

## Parameter space

| Dimension | Values | Notes |
|-----------|-------:|-------|
| Isolates | 100 | Batched 20 at a time |
| Dates | 20,004 | Quarterly, -2000 to +3000 CE |
| Bodies (geocentric) | 14 | Sun through OscuApog (0-13) |
| Bodies (heliocentric) | 9 | Planets + Earth |
| Bodies (barycentric) | 10 | Sun + planets + Earth (SE only) |
| Standard ayanamsas | 47 | All seSidm* modes (0-46) |
| User-defined ayanamsas | 5 | seSidmUser (255) with varying t0/ayanT0 |
| Locations | 7+1 | 7 cities + Hammerfest 70°N (polar) |
| House systems | 11 | Placidus through Morinus |
| Ephemeris engines | 2 | Moshier + Swiss Ephemeris (.se1 files) |
| Fixed stars | 10 | Sirius, Aldebaran, Regulus, etc. |
| Coordinate modes | 10 | Tropical, equatorial, truepos, etc. |

### Coordinate modes tested (per engine)

| Mode | Flags | Bodies |
|------|-------|--------|
| Tropical | `SPEED` | 14 geocentric |
| Equatorial | `SPEED + EQUATORIAL` | 14 geocentric |
| True position | `SPEED + TRUEPOS` | 14 geocentric |
| No aberration | `SPEED + NOABERR` | 14 geocentric |
| No deflection | `SPEED + NOGDEFL` | 14 geocentric |
| Heliocentric | `SPEED + HELCTR` | 9 planets + Earth |
| Helio equatorial | `SPEED + HELCTR + EQUATORIAL` | 9 planets + Earth |
| Barycentric (SE) | `SPEED + BARYCTR` | 10 (Sun+planets) |
| Bary equatorial | `SPEED + BARYCTR + EQUATORIAL` | 10 (Sun+planets) |
| Sidereal × 52 | `SPEED + SIDEREAL` | 14 geocentric |

## Volume breakdown (estimated per isolate)

| Module | Est. calls |
|--------|----------:|
| calcUt (tropical+helio+bary) | ~4.3M |
| calcUt (sidereal × 52 ayanamsas) | ~27.4M |
| calc (ET variant, every 5th date) | ~860K |
| houses (all 5 variants × locations × systems) | ~2.9M |
| housePos (subset) | ~225K |
| ayanamsa (5 methods × 52 ayanamsas) | ~5.1M |
| dateTime (15 methods) | ~300K |
| positionExt (6 methods × 6 bodies) | ~180K |
| fixedStar (10 stars × yearly dates) | ~100K |
| coordinate (5 methods) | ~100K |
| utility (9 calls per date) | ~180K |
| crossing (8 methods, sampled) | ~1.2K |
| riseSet (2 methods, sampled) | ~5.6K |
| eclipse (10 methods, chained) | ~200 |
| heliacal (3 methods, 5 dates) | ~45 |
| gauquelin (2 methods, sampled) | ~450 |
| name + config | ~50 |
| **Total per isolate** | **~41M** |
| **100 isolates** | **~4.1B** |

## Expected error paths

- **Placidus/Koch at polar latitudes** — these house systems fail at 70°N;
  `SweException` caught and counted.
- **Circumpolar rise/set** — `riseTrans` returns `returnFlag == -2` for the
  polar location near solstices; counted as expected error.
- **Crossing search failures** — some dates have no crossing within the C
  library's search window; `SweException` caught.
- **Fixed star file missing** — if `sefstars.txt` is not in `ephe/`, all
  fixed star calls throw; counted as errors, not a test failure.
- **Heliacal failures** — heliacal computations can fail for distant dates;
  `SweException` caught.

## State confusion strategy

Between every workload module, `_scrambleState()` sets:
- Ayanamsa to `stdAyanamsas[isolateId % 47]`
- Topocentric origin to `locations[isolateId % 8]`
- Nutation interpolation to `isolateId.isEven`

Within the calc workload, sidereal specs cycle through all 47 standard + 5
user-defined ayanamsas on every date. This creates maximal global state churn.

## Comparison with stress test 0.1

| | Stress test 0.1 | Stress test 0.2 |
|---|---|---|
| Methods tested | 2 (`calcUt`, `houses`) | 88 (full API) |
| Total calcs | 3.06B | 4.11B |
| Wall time | ~100 min | ~126 min |
| Throughput | ~510K/sec | ~545K/sec |
| Isolates | 100 | 100 |
| Ephemeris engines | 2 | 2 |
| Verification checks | 4 | 6 |
| Error path testing | No | Yes |

## How to run

```
dart test test/stress-test-0.2/stress_test_0_2.dart
```

Requires `.se1` ephemeris data files in `ephe/` for Swiss Ephemeris mode calcs.
Moshier calcs need no data files. Fixed star methods need `sefstars.txt` in
`ephe/` (degrades gracefully if missing). The test has a 180-minute timeout.
Expected run time is ~125 minutes on a modern x86_64 machine.
