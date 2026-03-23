# Stress Test

`test/stress_test.dart`

## What it does

Spawns 100 Dart isolates (batched through a pool of 20 concurrent workers) and
hammers the Swiss Ephemeris C library with **3.06 billion calculations** —
planetary positions and house cusps across 5,000 years of quarterly dates,
14 celestial bodies, all 47 ayanamsas, 7 geographic locations, 11 house systems,
and both ephemeris engines (Moshier analytical + Swiss Ephemeris .se1 files).

Each isolate gets its own copy of the compiled `.so` to guarantee true C-level
isolation. After all isolates finish, the test verifies that:

1. Every isolate completed without error.
2. Isolates assigned the same ayanamsa produced bit-identical reference values
   (proving no state contamination from concurrent C globals).
3. Different ayanamsas produced distinct reference values (proving the sidereal
   mode was actually applied, not silently ignored).

## Why it exists

Swiss Ephemeris uses C global state internally — the sidereal mode, ephemeris
path, and topocentric coordinates are all process-wide globals. On Linux/macOS,
`dlopen` deduplicates shared libraries by device+inode, so two isolates loading
the same `.so` path silently share that global state. This is a correctness
hazard: one isolate sets Lahiri ayanamsa, another sets Raman, and whichever
runs last wins — both get the same (wrong) result.

The workaround is to copy the `.so` to a unique temp path per isolate. This
test proves that workaround holds under real load — not just for two isolates
in a unit test, but for 100 isolates running billions of calculations in
parallel across both ephemeris engines, all coordinate systems, and all
47 ayanamsa modes.

The earlier `isolate_test.dart` proves the mechanism works. This test proves it
**scales**.

### Why two ephemeris engines

Moshier is a self-contained analytical model — fast, no files needed. Swiss
Ephemeris mode reads from `.se1` data files on disk and is higher precision.
The two engines exercise different code paths in the C library. Under concurrent
load with 20 isolates all reading the same `.se1` files simultaneously, this
tests both the isolation of C globals *and* safe concurrent file I/O (the .se1
files are read-only, so POSIX guarantees safety, but it's worth proving under
load).

### Why all 47 ayanamsas

The sidereal mode is set via C global state (`swe_set_sid_mode`). This is the
most dangerous global for isolate contamination — a wrong ayanamsa silently
shifts every sidereal longitude by up to several degrees, producing plausible
but incorrect results. Testing all 47 modes means every isolate cycles through
every ayanamsa on every date, maximizing the window for cross-isolate leakage.

## Parameter space

| Dimension        | Values | Notes                                         |
|------------------|-------:|-----------------------------------------------|
| Isolates         |    100 | Batched 20 at a time                          |
| Dates            | 20,004 | Quarterly, -2000 to +3000 CE                  |
| Bodies           |     14 | Sun through OscuApog (0–13)                   |
| Ayanamsas        |     47 | All standard modes (0–46)                     |
| Locations        |      7 | Delhi, London, NYC, Sydney, Tokyo, 0/0, Rio   |
| House systems    |     11 | Placidus through Morinus                      |
| Ephemeris engines|      2 | Moshier + Swiss Ephemeris (.se1 files)        |

### Coordinate modes tested (per engine)

| Mode              | Flags                            | Bodies            |
|-------------------|----------------------------------|-------------------|
| Tropical          | `SPEED`                          | 14 geocentric     |
| Equatorial        | `SPEED + EQUATORIAL`             | 14 geocentric     |
| True position     | `SPEED + TRUEPOS`                | 14 geocentric     |
| No aberration     | `SPEED + NOABERR`                | 14 geocentric     |
| No deflection     | `SPEED + NOGDEFL`                | 14 geocentric     |
| Heliocentric      | `SPEED + HELCTR`                 | 9 planets + Earth |
| Helio equatorial  | `SPEED + HELCTR + EQUATORIAL`    | 9 planets + Earth |
| Barycentric (SE)  | `SPEED + BARYCTR`                | 10 (Sun+planets)  |
| Bary equatorial   | `SPEED + BARYCTR + EQUATORIAL`   | 10 (Sun+planets)  |
| Sidereal × 47     | `SPEED + SIDEREAL`               | 14 geocentric     |

Barycentric is Swiss Ephemeris only — Moshier does not support it.

### Per-isolate breakdown

- **Planetary calcs**: 20,004 dates × 1,512 calcs/date + 1 reference = ~30.2M
- **House calcs**: 5,001 dates × 7 locations × 11 systems = ~385K
- **Total per isolate**: ~30.6M
- **100 isolates**: **~3.06 billion**

## What's excluded and why

All exclusions are to avoid runtime bounds-checking. The point is to stress the
calculation engine, not to test which bodies work at which dates.

- **Earth (body 14)**: geocentric position of Earth is meaningless. Included in
  heliocentric and barycentric modes where it makes sense.
- **Chiron (body 15)**: restricted to JD 1967601–3419437 (~675–3000 CE) in both
  Moshier and Swiss Ephemeris engines. Our date range starts at -2000 CE, so
  Chiron would fail for the first ~2,675 years. Excluded entirely rather than
  adding if-statements.
- **Barycentric + Moshier**: Moshier engine does not support barycentric
  coordinates at all (`SweException: barycentric Moshier positions are not
  supported`). Barycentric is tested with Swiss Ephemeris only.
- **Moon/nodes/apogees + heliocentric/barycentric**: these are geocentric
  concepts. Heliocentric Moon is undefined, nodes and apogees are Earth-relative.
- **Pholus, asteroids, fictitious bodies**: restricted ranges or require
  additional data files. Excluded for the same reason as Chiron.

## Results

On a 12-core machine (AMD Ryzen 5 7600):

```
=== STRESS TEST RESULTS ===
Isolates: 100 (pool of 20)
Ephemerides: Moshier + Swiss Ephemeris
Planetary calcs: 3.02B
House calcs: 38.5M
Total calcs: 3.06B
Wall time: 98m 50s
Throughput: 516.5K calcs/sec
Ayanamsas verified: 47 (all 47)
Coordinate modes: tropical, equatorial, true position, no-aberration,
  no-deflection, heliocentric, barycentric (SE), sidereal × 47
Isolation: PASS
===========================
```

Wall time and throughput depend on hardware. The test has a 120-minute timeout.

## How to run

```
dart test test/stress_test.dart
```

Requires `.se1` ephemeris data files in `ephe/` for the Swiss Ephemeris mode
calcs. Moshier calcs need no data files.
