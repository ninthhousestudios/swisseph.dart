@Tags(['stress'])
@Timeout(Duration(minutes: 120))
library;

import 'dart:io';
import 'dart:isolate';
import 'package:test/test.dart';
import 'package:swisseph/swisseph.dart';

// ---------------------------------------------------------------------------
// Pre-built valid parameter space.
// Every combination here is known-valid — no runtime bounds checking.
// ---------------------------------------------------------------------------

/// Geocentric bodies for Moshier: Sun through OscuApog (0–13).
/// Skips Earth (14) — meaningless geocentric.
/// Skips Chiron (15) — Moshier restricts to JD 1967601–3419437 (~675–3000 CE).
const List<int> moshierGeocentricBodies = [
  seSun, seMoon, seMercury, seVenus, seMars, seJupiter, seSaturn,
  seUranus, seNeptune, sePluto, seMeanNode, seTrueNode, seMeanApog,
  seOscuApog,
];

/// Geocentric bodies for SwissEph: same as Moshier.
/// Chiron restricted to JD 1967601–3419437 (~675–3000 CE) in both engines.
const List<int> sweGeocentricBodies = [
  seSun, seMoon, seMercury, seVenus, seMars, seJupiter, seSaturn,
  seUranus, seNeptune, sePluto, seMeanNode, seTrueNode, seMeanApog,
  seOscuApog,
];

/// Heliocentric bodies: planets only.
/// Skips Sun (it IS the center), Moon, nodes, apogees (geocentric concepts).
/// Includes Earth (14).
const List<int> helioBodies = [
  seMercury, seVenus, seMars, seJupiter, seSaturn,
  seUranus, seNeptune, sePluto, seEarth,
];

/// Barycentric bodies (SwissEph only — Moshier doesn't support barycentric).
/// Sun + planets. Skips Moon, nodes, apogees.
const List<int> baryBodies = [
  seSun, seMercury, seVenus, seMars, seJupiter, seSaturn,
  seUranus, seNeptune, sePluto, seEarth,
];

/// All 47 standard ayanamsa modes.
const List<int> ayanamsas = [
  seSidmFaganBradley, seSidmLahiri, seSidmDeluce, seSidmRaman,
  seSidmUshashashi, seSidmKrishnamurti, seSidmDjwhalKhul,
  seSidmYukteshwar, seSidmJnBhasin, seSidmBabylKugler1,
  seSidmBabylKugler2, seSidmBabylKugler3, seSidmBabylHuber,
  seSidmBabylEtpsc, seSidmAldebaran15tau, seSidmHipparchos,
  seSidmSassanian, seSidmGalcent0sag, seSidmJ2000, seSidmJ1900,
  seSidmB1950, seSidmSuryasiddhanta, seSidmSuryasiddhantaMsun,
  seSidmAryabhata, seSidmAryabhataMsun, seSidmSsRevati, seSidmSsCitra,
  seSidmTrueCitra, seSidmTrueRevati, seSidmTruePushya,
  seSidmGalcentRgilbrand, seSidmGalequIau1958, seSidmGalequTrue,
  seSidmGalequMula, seSidmGalalignMardyks, seSidmTrueMula,
  seSidmGalcentMulaWilhelm, seSidmAryabhata522, seSidmBabylBritton,
  seSidmTrueSheoran, seSidmGalcentCochrane, seSidmGalequFiorenza,
  seSidmValensMoon, seSidmLahiri1940, seSidmLahiriVp285,
  seSidmKrishnamurtiVp291, seSidmLahiriIcrc,
];

/// House systems.
const List<int> houseSystems = [
  hsysPlacidus, hsysKoch, hsysPorphyry, hsysRegiomontanus,
  hsysCampanus, hsysEqual, hsysWholeSign, hsysAlcabitius,
  hsysTopocentric, hsysMeridian, hsysMorinus,
];

/// Geographic locations: (lat, lon) pairs.
const List<(double, double)> locations = [
  (28.6139, 77.2090), // Delhi
  (51.5074, -0.1278), // London
  (40.7128, -74.0060), // New York
  (-33.8688, 151.2093), // Sydney
  (35.6762, 139.6503), // Tokyo
  (0.0, 0.0), // Null Island
  (-22.9068, -43.1729), // Rio de Janeiro
];

// ---------------------------------------------------------------------------
// Calc specs — flat list of every valid (flags, body) combination.
// ---------------------------------------------------------------------------

class CalcSpec {
  final int flags;
  final int body;
  final bool isSidereal; // worker cycles all 47 ayanamsas for these
  const CalcSpec(this.flags, this.body, this.isSidereal);
}

List<CalcSpec> _buildCalcSpecs() {
  final specs = <CalcSpec>[];

  // --- Moshier modes ---

  const moshierGeoFlags = [
    seFlgMosEph | seFlgSpeed,
    seFlgMosEph | seFlgSpeed | seFlgEquatorial,
    seFlgMosEph | seFlgSpeed | seFlgTruePos,
    seFlgMosEph | seFlgSpeed | seFlgNoAberr,
    seFlgMosEph | seFlgSpeed | seFlgNoGdefl,
  ];
  for (final flags in moshierGeoFlags) {
    for (final body in moshierGeocentricBodies) {
      specs.add(CalcSpec(flags, body, false));
    }
  }

  // Moshier heliocentric
  const moshierHelioFlags = [
    seFlgMosEph | seFlgSpeed | seFlgHelCtr,
    seFlgMosEph | seFlgSpeed | seFlgHelCtr | seFlgEquatorial,
  ];
  for (final flags in moshierHelioFlags) {
    for (final body in helioBodies) {
      specs.add(CalcSpec(flags, body, false));
    }
  }
  // Moshier barycentric: NOT SUPPORTED — excluded entirely.

  // Moshier sidereal (ayanamsa cycling in worker)
  for (final body in moshierGeocentricBodies) {
    specs.add(CalcSpec(seFlgMosEph | seFlgSpeed | seFlgSidereal, body, true));
  }

  // --- Swiss Ephemeris file modes ---

  const sweGeoFlags = [
    seFlgSwiEph | seFlgSpeed,
    seFlgSwiEph | seFlgSpeed | seFlgEquatorial,
    seFlgSwiEph | seFlgSpeed | seFlgTruePos,
    seFlgSwiEph | seFlgSpeed | seFlgNoAberr,
    seFlgSwiEph | seFlgSpeed | seFlgNoGdefl,
  ];
  for (final flags in sweGeoFlags) {
    for (final body in sweGeocentricBodies) {
      specs.add(CalcSpec(flags, body, false));
    }
  }

  // SwissEph heliocentric
  const sweHelioFlags = [
    seFlgSwiEph | seFlgSpeed | seFlgHelCtr,
    seFlgSwiEph | seFlgSpeed | seFlgHelCtr | seFlgEquatorial,
  ];
  for (final flags in sweHelioFlags) {
    for (final body in helioBodies) {
      specs.add(CalcSpec(flags, body, false));
    }
  }

  // SwissEph barycentric
  const sweBaryFlags = [
    seFlgSwiEph | seFlgSpeed | seFlgBaryCtr,
    seFlgSwiEph | seFlgSpeed | seFlgBaryCtr | seFlgEquatorial,
  ];
  for (final flags in sweBaryFlags) {
    for (final body in baryBodies) {
      specs.add(CalcSpec(flags, body, false));
    }
  }

  // SwissEph sidereal (ayanamsa cycling in worker)
  for (final body in sweGeocentricBodies) {
    specs.add(CalcSpec(seFlgSwiEph | seFlgSpeed | seFlgSidereal, body, true));
  }

  return specs;
}

/// Quarterly dates across -2000 to +3000 CE = 20,004 dates.
List<(int year, int month)> _buildDates() {
  final dates = <(int, int)>[];
  for (int year = -2000; year <= 3000; year++) {
    dates.add((year, 1));
    dates.add((year, 4));
    dates.add((year, 7));
    dates.add((year, 10));
  }
  return dates;
}

// ---------------------------------------------------------------------------
// Isolate workload
// ---------------------------------------------------------------------------

class WorkerConfig {
  final String libPath;
  final int isolateId;
  final int assignedAyanamsa;
  final String ephePath;
  final List<CalcSpec> specs;
  final List<(int, int)> dates;
  final SendPort resultPort;

  WorkerConfig({
    required this.libPath,
    required this.isolateId,
    required this.assignedAyanamsa,
    required this.ephePath,
    required this.specs,
    required this.dates,
    required this.resultPort,
  });
}

class WorkerResult {
  final int isolateId;
  final int assignedAyanamsa;
  final int calcCount;
  final int houseCount;
  final double referenceLongitude;
  final int elapsedMs;
  final String? error;

  WorkerResult({
    required this.isolateId,
    required this.assignedAyanamsa,
    required this.calcCount,
    required this.houseCount,
    required this.referenceLongitude,
    required this.elapsedMs,
    this.error,
  });
}

void _isolateWorker(WorkerConfig config) {
  final sw = Stopwatch()..start();
  int calcCount = 0;
  int houseCount = 0;

  try {
    final swe = SwissEph(config.libPath);
    swe.setEphePath(config.ephePath);

    // Reference value for isolation verification:
    // Sun sidereal longitude at J2000.0 with assigned ayanamsa (Moshier).
    swe.setSidMode(config.assignedAyanamsa);
    final jd2000 = swe.julday(2000, 1, 1, 0.0);
    final ref = swe.calcUt(
      jd2000, seSun, seFlgMosEph | seFlgSpeed | seFlgSidereal,
    );
    calcCount++;
    final refLon = ref.longitude;

    // --- Planetary calculations ---
    for (final (year, month) in config.dates) {
      final jd = swe.julday(year, month, 1, 0.0);

      for (final spec in config.specs) {
        if (spec.isSidereal) {
          for (final aya in ayanamsas) {
            swe.setSidMode(aya);
            swe.calcUt(jd, spec.body, spec.flags);
            calcCount++;
          }
        } else {
          swe.calcUt(jd, spec.body, spec.flags);
          calcCount++;
        }
      }
    }

    // --- House calculations (once per year, mid-year noon) ---
    for (final (year, month) in config.dates) {
      if (month != 7) continue;
      final jd = swe.julday(year, month, 1, 12.0);
      for (final (lat, lon) in locations) {
        for (final hsys in houseSystems) {
          swe.houses(jd, lat, lon, hsys);
          houseCount++;
        }
      }
    }

    swe.close();
    sw.stop();

    config.resultPort.send(WorkerResult(
      isolateId: config.isolateId,
      assignedAyanamsa: config.assignedAyanamsa,
      calcCount: calcCount,
      houseCount: houseCount,
      referenceLongitude: refLon,
      elapsedMs: sw.elapsedMilliseconds,
    ));
  } catch (e, st) {
    sw.stop();
    config.resultPort.send(WorkerResult(
      isolateId: config.isolateId,
      assignedAyanamsa: config.assignedAyanamsa,
      calcCount: calcCount,
      houseCount: houseCount,
      referenceLongitude: -1,
      elapsedMs: sw.elapsedMilliseconds,
      error: '$e\n$st',
    ));
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _findLibrary() {
  final candidates = Directory('.dart_tool')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) =>
          f.path.endsWith('libswisseph.so') ||
          f.path.endsWith('libswisseph.dylib'))
      .map((f) => f.path)
      .toList();
  if (candidates.isEmpty) {
    throw StateError('libswisseph not found in .dart_tool/');
  }
  return candidates.first;
}

String _copyLibForIsolate(String sourcePath, int id) {
  final tmpDir = Directory.systemTemp.createTempSync('swisseph_stress_');
  final ext = sourcePath.endsWith('.dylib') ? 'dylib' : 'so';
  final destPath = '${tmpDir.path}/libswisseph_$id.$ext';
  File(sourcePath).copySync(destPath);
  return destPath;
}

String _formatCount(int n) {
  if (n >= 1e9) return '${(n / 1e9).toStringAsFixed(2)}B';
  if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}M';
  if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(1)}K';
  return n.toString();
}

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------

void main() {
  late String baseLibPath;
  late String ephePath;
  final specs = _buildCalcSpecs();
  final dates = _buildDates();

  // Tally expected volume
  final nonSidereal = specs.where((s) => !s.isSidereal).length;
  final siderealBodies = specs.where((s) => s.isSidereal).length;
  final calcsPerDate = nonSidereal + (siderealBodies * ayanamsas.length);
  final houseDatesPerIsolate = dates.length ~/ 4;
  final housesPerIsolate =
      houseDatesPerIsolate * locations.length * houseSystems.length;
  final planetaryPerIsolate = dates.length * calcsPerDate + 1;
  final totalPerIsolate = planetaryPerIsolate + housesPerIsolate;

  stderr.writeln('=== STRESS TEST CONFIG ===');
  stderr.writeln('Ephemerides: Moshier + Swiss Ephemeris (.se1 files)');
  stderr.writeln('Dates: ${dates.length} (quarterly, -2000 to +3000 CE)');
  stderr.writeln('Calc specs: ${specs.length} '
      '($nonSidereal non-sidereal + $siderealBodies sidereal bodies × '
      '${ayanamsas.length} ayanamsas)');
  stderr.writeln('Calcs per date: $calcsPerDate');
  stderr.writeln('Per isolate: ~${_formatCount(planetaryPerIsolate)} planetary '
      '+ ${_formatCount(housesPerIsolate)} houses '
      '= ${_formatCount(totalPerIsolate)}');
  stderr.writeln('100 isolates: ~${_formatCount(totalPerIsolate * 100)} total');
  stderr.writeln('==========================\n');

  setUpAll(() {
    baseLibPath = _findLibrary();
    ephePath = Directory('ephe').absolute.path;
    if (!Directory(ephePath).existsSync()) {
      throw StateError('ephe/ directory not found — Swiss Ephemeris data files '
          'required for stress test');
    }
  });

  group('stress test', () {
    test('100 isolates through pool of 20, Moshier + SwissEph sweep',
        () async {
      const totalTasks = 100;
      const poolSize = 20;

      final taskConfigs = List.generate(totalTasks, (i) => (
        isolateId: i,
        assignedAyanamsa: ayanamsas[i % ayanamsas.length],
      ));

      final libPaths = List.generate(
        poolSize,
        (i) => _copyLibForIsolate(baseLibPath, i),
      );

      final results = <WorkerResult>[];
      final overallSw = Stopwatch()..start();

      try {
        for (int batch = 0; batch < totalTasks; batch += poolSize) {
          final batchEnd = (batch + poolSize).clamp(0, totalTasks);
          final futures = <Future<WorkerResult>>[];

          for (int i = batch; i < batchEnd; i++) {
            final task = taskConfigs[i];
            final libPath = libPaths[i % poolSize];
            final receivePort = ReceivePort();

            futures.add(() async {
              await Isolate.spawn(
                _isolateWorker,
                WorkerConfig(
                  libPath: libPath,
                  isolateId: task.isolateId,
                  assignedAyanamsa: task.assignedAyanamsa,
                  ephePath: ephePath,
                  specs: specs,
                  dates: dates,
                  resultPort: receivePort.sendPort,
                ),
              );
              return await receivePort.first as WorkerResult;
            }());
          }

          final batchResults = await Future.wait(futures);
          results.addAll(batchResults);

          final done = results.length;
          final totalCalcs = results.fold<int>(
            0, (sum, r) => sum + r.calcCount + r.houseCount,
          );
          final elapsed = overallSw.elapsed;
          final rate = elapsed.inSeconds > 0
              ? _formatCount((totalCalcs / elapsed.inSeconds).toInt())
              : '---';
          stderr.writeln(
            '  [$done/$totalTasks] '
            '${_formatCount(totalCalcs)} calcs, '
            '${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s, '
            '$rate calcs/sec',
          );
        }

        overallSw.stop();

        // --- Verification ---

        final errors = results.where((r) => r.error != null).toList();
        if (errors.isNotEmpty) {
          stderr.writeln('ERRORS (first 3):');
          for (final e in errors.take(3)) {
            stderr.writeln('  isolate ${e.isolateId} '
                '(${_formatCount(e.calcCount)} calcs done): ${e.error}');
          }
        }
        expect(errors, isEmpty,
            reason: 'All isolates should complete without error');

        // Isolation: same ayanamsa → same reference longitude
        final byAyanamsa = <int, List<double>>{};
        for (final r in results) {
          byAyanamsa
              .putIfAbsent(r.assignedAyanamsa, () => [])
              .add(r.referenceLongitude);
        }
        for (final entry in byAyanamsa.entries) {
          final lons = entry.value;
          final first = lons.first;
          for (final lon in lons) {
            expect((lon - first).abs(), lessThan(1e-8),
                reason:
                    'Ayanamsa ${entry.key}: all isolates should agree on '
                    'reference longitude (got spread of '
                    '${lons.map((l) => l.toStringAsFixed(10)).toSet()})');
          }
        }

        // Different ayanamsas → different reference longitudes
        final uniqueLons = byAyanamsa.values.map((v) => v.first).toSet();
        expect(uniqueLons.length, equals(byAyanamsa.length),
            reason: 'Each ayanamsa should produce a distinct reference value');

        // Stats
        final totalCalcs = results.fold<int>(
          0, (sum, r) => sum + r.calcCount + r.houseCount,
        );
        final totalPlanetaryCalcs = results.fold<int>(
          0, (sum, r) => sum + r.calcCount,
        );
        final totalHouseCalcs = results.fold<int>(
          0, (sum, r) => sum + r.houseCount,
        );
        final elapsed = overallSw.elapsed;
        final calcsPerSec = totalCalcs / elapsed.inSeconds;

        stderr.writeln('\n=== STRESS TEST RESULTS ===');
        stderr.writeln('Isolates: $totalTasks (pool of $poolSize)');
        stderr.writeln('Ephemerides: Moshier + Swiss Ephemeris');
        stderr.writeln('Planetary calcs: ${_formatCount(totalPlanetaryCalcs)}');
        stderr.writeln('House calcs: ${_formatCount(totalHouseCalcs)}');
        stderr.writeln('Total calcs: ${_formatCount(totalCalcs)}');
        stderr.writeln('Wall time: ${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s');
        stderr.writeln('Throughput: ${_formatCount(calcsPerSec.toInt())} calcs/sec');
        stderr.writeln('Ayanamsas verified: ${byAyanamsa.length} (all 47)');
        stderr.writeln('Coordinate modes: tropical, equatorial, true position, '
            'no-aberration, no-deflection, heliocentric, barycentric (SE), '
            'sidereal × 47');
        stderr.writeln('Isolation: PASS');
        stderr.writeln('===========================\n');
      } finally {
        for (final path in libPaths) {
          try {
            final file = File(path);
            file.deleteSync();
            file.parent.deleteSync();
          } catch (_) {}
        }
      }
    });
  });
}
