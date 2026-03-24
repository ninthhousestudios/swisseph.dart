/// Generate reference values from swetest for cross-validation with swisseph.dart.
///
/// swetest is the official test program shipped with the Swiss Ephemeris C library.
/// This script calls the swetest binary to compute reference values and writes them
/// to reference_data.json for comparison by cross_validation_test.dart.
///
/// Run:
///   cd <swisseph.dart>
///   dart run test/swetest-validation/generate_reference.dart [swetest_path]
///
/// Default swetest path: ../../swisseph/bin/swetest

import 'dart:convert';
import 'dart:io';

late String _sweetestPath;

// ── Test parameters (same as libaditya-validation) ──────────────────────────

const _dates = [
  (2000, 1, 1, 0.0), // J2000.0 midnight
  (2000, 1, 1, 12.0), // J2000.0 noon
  (1985, 1, 1, 0.0), // Known reference date
  (1990, 6, 15, 18.5), // Roundtrip test date
  (2024, 3, 20, 12.0), // Vernal equinox 2024 (approx)
  (1947, 8, 15, 0.0), // Historical: India independence
  (2050, 12, 31, 23.99), // Future date
];

// (swe_id, swetest_code, name)
const _planets = [
  (0, '0', 'Sun'),
  (1, '1', 'Moon'),
  (2, '2', 'Mercury'),
  (3, '3', 'Venus'),
  (4, '4', 'Mars'),
  (5, '5', 'Jupiter'),
  (6, '6', 'Saturn'),
  (7, '7', 'Uranus'),
  (8, '8', 'Neptune'),
  (9, '9', 'Pluto'),
  (10, 'm', 'mean Node'),
  (11, 't', 'true Node'),
  (15, 'D', 'Chiron'),
];

// (char, code, name)
const _houseSystems = [
  ('P', 0x50, 'Placidus'),
  ('K', 0x4B, 'Koch'),
  ('O', 0x4F, 'Porphyry'),
  ('R', 0x52, 'Regiomontanus'),
  ('C', 0x43, 'Campanus'),
  ('E', 0x45, 'Equal'),
  ('W', 0x57, 'Whole Sign'),
  ('B', 0x42, 'Alcabitius'),
  ('T', 0x54, 'Topocentric'),
  ('X', 0x58, 'Meridian'),
  ('M', 0x4D, 'Morinus'),
];

// (lat, lon, alt, name)
const _locations = [
  (38.8977, -77.0365, 0.0, 'Washington DC'),
  (28.6139, 77.2090, 0.0, 'New Delhi'),
  (51.5074, -0.1278, 0.0, 'London'),
  (-33.8688, 151.2093, 0.0, 'Sydney'),
  (0.0, 0.0, 0.0, 'Null Island'),
  (64.1466, -21.9426, 0.0, 'Reykjavik'),
  (-54.8019, -68.3030, 0.0, 'Ushuaia'),
];

// (swe_id, name)
const _ayanamsas = [
  (0, 'Fagan-Bradley'),
  (1, 'Lahiri'),
  (3, 'Raman'),
  (5, 'Krishnamurti'),
  (7, 'Yukteshwar'),
  (8, 'JN Bhasin'),
  (2, 'DeLuce'),
  (23, 'Aryabhata'),
  (27, 'True Citra'),
  (28, 'True Revati'),
  (29, 'True Pushya'),
  (36, 'GalCent Mula Wilhelm'),
  (15, 'Hipparchos'),
  (16, 'Sassanian'),
];

// ── Helpers ─────────────────────────────────────────────────────────────────

/// Format date for swetest -b flag (D.M.Y, European).
String _fmtDate(int y, int m, int d) => '$d.$m.$y';

/// Format decimal hours as HH:MM:SS.S for swetest -ut flag.
String _fmtTime(double h) {
  final hours = h.truncate();
  final remainder = (h - hours) * 60;
  final mins = remainder.truncate();
  final secs = (remainder - mins) * 60;
  // Use enough precision to avoid rounding issues
  final secStr = secs.toStringAsFixed(1);
  return '$hours:${mins.toString().padLeft(2, '0')}:${secStr.padLeft(4, '0')}';
}

/// Compute Julian Day Number (Gregorian calendar).
/// This is the standard algorithm — used to convert swetest date/time output
/// back to JD for rise/set reference values.
double _julday(int year, int month, int day, double hour) {
  var y = year;
  var m = month;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = y ~/ 100;
  final b = 2 - a + (a ~/ 4);
  return (365.25 * (y + 4716)).floor() +
      (30.6001 * (m + 1)).floor() +
      day +
      hour / 24.0 +
      b -
      1524.5;
}

/// Run swetest with given arguments and return stdout.
Future<String> _run(List<String> args) async {
  final result = await Process.run(_sweetestPath, args);
  final stdout = (result.stdout as String).trim();
  // swetest prints warnings to stderr (e.g., "using Moshier eph")
  // These are expected — only fail on actual errors
  if (result.exitCode != 0) {
    final stderr = (result.stderr as String).trim();
    throw Exception('swetest failed (exit ${result.exitCode}):\n'
        '  args: $args\n  stderr: $stderr');
  }
  return stdout;
}

/// Run swetest for a single planet at a given date, return parsed decimal values.
/// Format string controls what values are returned.
///
/// Throws if swetest outputs an error (e.g., missing ephemeris file for Chiron).
Future<List<double>> _runPlanet(
  int year, int month, int day, double hour,
  String planetCode,
  String fmt, {
  List<String> extraArgs = const [],
}) async {
  final output = await _run([
    '-b${_fmtDate(year, month, day)}',
    '-ut${_fmtTime(hour)}',
    '-p$planetCode',
    '-f$fmt',
    '-head',
    '-emos',
    ...extraArgs,
  ]);
  // swetest prints "error: ..." to stdout for some failures (e.g., missing
  // asteroid ephemeris files) but still exits 0 with zero values.
  if (output.contains('error:')) {
    throw Exception('swetest error: $output');
  }
  return output
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .map(double.parse)
      .toList();
}

// ── Generators ──────────────────────────────────────────────────────────────

/// 1. Julian Day conversion
///
/// Uses _julday() (standard Meeus algorithm) for full-precision JD values.
/// swetest's -fJ output truncates to ~5 decimal places which loses precision.
/// Both _julday() and swe_julday() implement the same algorithm.
List<Map<String, dynamic>> _generateJulday() {
  return [
    for (final (y, m, d, h) in _dates)
      {
        'input': {'year': y, 'month': m, 'day': d, 'hour': h},
        'jd': _julday(y, m, d, h),
        // The input date is the expected revjul output
        'revjul': {'year': y, 'month': m, 'day': d, 'hour': h},
      },
  ];
}

/// 2. Planet positions — Moshier (tropical)
Future<List<Map<String, dynamic>>> _generatePlanetPositions() async {
  final results = <Map<String, dynamic>>[];
  for (final (y, m, d, h) in _dates) {
    // Use _julday() for full-precision JD. swetest's -fJ truncates to ~5
    // decimal places, which causes cascading position errors when the test
    // feeds the truncated JD to calcUt.
    final jd = _julday(y, m, d, h);

    for (final (pid, pcode, pname) in _planets) {
      try {
        // Format: lon lat dist lon_speed lat_speed dist_speed
        final vals = await _runPlanet(y, m, d, h, pcode, 'lbRss');
        results.add({
          'date': {'year': y, 'month': m, 'day': d, 'hour': h},
          'jd': jd,
          'body': pid,
          'body_name': pname,
          'flags': 4 | 256, // MOSEPH | SPEED
          'flags_desc': 'MOSEPH|SPEED',
          'longitude': vals[0],
          'latitude': vals[1],
          'distance': vals[2],
          'longitude_speed': vals[3],
          'latitude_speed': vals[4],
          'distance_speed': vals[5],
        });
      } catch (e) {
        results.add({
          'date': {'year': y, 'month': m, 'day': d, 'hour': h},
          'body': pid,
          'body_name': pname,
          'error': e.toString(),
        });
      }
    }
  }
  return results;
}

/// 3. Sidereal positions — multiple ayanamsas
Future<List<Map<String, dynamic>>> _generateSiderealPositions() async {
  final results = <Map<String, dynamic>>[];
  final jdJ2000 = _julday(2000, 1, 1, 0.0);
  final jd2024 = _julday(2024, 3, 20, 12.0);

  for (final (jd, jdDate, jdLabel) in [
    (jdJ2000, (2000, 1, 1, 0.0), 'J2000'),
    (jd2024, (2024, 3, 20, 12.0), '2024-03-20'),
  ]) {
    final (y, m, d, h) = jdDate;
    for (final (sidId, sidName) in _ayanamsas) {
      // Get ayanamsa value
      final ayaOutput = await _run([
        '-b${_fmtDate(y, m, d)}',
        '-ut${_fmtTime(h)}',
        '-pb',
        '-fl',
        '-head',
        '-emos',
        '-sid$sidId',
      ]);
      final aya = double.parse(ayaOutput.trim());

      // Get sidereal Sun and Moon
      for (final (pid, pcode, pname) in [
        (0, '0', 'Sun'),
        (1, '1', 'Moon'),
      ]) {
        final vals = await _runPlanet(
          y, m, d, h, pcode, 'lbss',
          extraArgs: ['-sid$sidId'],
        );
        results.add({
          'jd': jd,
          'jd_label': jdLabel,
          'ayanamsa_id': sidId,
          'ayanamsa_name': sidName,
          'ayanamsa_value': aya,
          'body': pid,
          'body_name': pname,
          'longitude': vals[0],
          'latitude': vals[1],
          'longitude_speed': vals[2],
        });
      }
    }
  }
  return results;
}

/// 4. Ayanamsa values at multiple dates
Future<List<Map<String, dynamic>>> _generateAyanamsaValues() async {
  final results = <Map<String, dynamic>>[];
  for (final (y, m, d, h) in _dates) {
    final jd = _julday(y, m, d, h);
    for (final (sidId, sidName) in _ayanamsas) {
      final output = await _run([
        '-b${_fmtDate(y, m, d)}',
        '-ut${_fmtTime(h)}',
        '-pb',
        '-fl',
        '-head',
        '-emos',
        '-sid$sidId',
      ]);
      final value = double.parse(output.trim());
      results.add({
        'date': {'year': y, 'month': m, 'day': d, 'hour': h},
        'jd': jd,
        'ayanamsa_id': sidId,
        'ayanamsa_name': sidName,
        'value': value,
      });
    }
  }
  return results;
}

/// 5. Ayanamsa names — from swetest planet name output with sidereal mode
///
/// swetest doesn't have a direct "get ayanamsa name" command, so we capture
/// the names that swe_get_ayanamsa_name() returns. These are deterministic
/// string lookups from the C library — hardcoded here from the Swiss Ephemeris
/// source to avoid needing to parse swetest's banner output.
List<Map<String, dynamic>> _generateAyanamsaNames() {
  // These names come from swe_get_ayanamsa_name() in the C library.
  // They are static string lookups, not computed values.
  const names = {
    0: 'Fagan/Bradley',
    1: 'Lahiri',
    2: 'De Luce',
    3: 'Raman',
    5: 'Krishnamurti',
    7: 'Yukteshwar',
    8: 'J.N. Bhasin',
    15: 'Hipparchos',
    16: 'Sassanian',
    23: 'Aryabhata',
    27: 'True Citra',
    28: 'True Revati',
    29: 'True Pushya (PVRN Rao)',
    36: 'Dhruva/Gal.Center/Mula (Wilhelm)',
  };
  return [
    for (final (sidId, _) in _ayanamsas)
      {
        'id': sidId,
        'swe_name': names[sidId]!,
      },
  ];
}

/// 6. House cusps — multiple systems × locations × dates
Future<List<Map<String, dynamic>>> _generateHouseCusps() async {
  final results = <Map<String, dynamic>>[];
  const houseDates = [
    (2000, 1, 1, 12.0),
    (2024, 3, 20, 12.0),
  ];

  for (final (y, m, d, h) in houseDates) {
    final jd = _julday(y, m, d, h);
    for (final (lat, lon, _, locName) in _locations) {
      for (final (hsysChar, hsysCode, hsysName) in _houseSystems) {
        try {
          // Use -p0 to get just Sun (1 planet line), then houses
          // Output with -fl gives decimal longitudes, one per line:
          //   line 0: Sun longitude
          //   lines 1-12: house cusps 1-12
          //   lines 13-20: Asc, MC, ARMC, Vertex, equat.Asc, co-Asc Koch,
          //                 co-Asc Munkasey, Polar Asc
          final output = await _run([
            '-b${_fmtDate(y, m, d)}',
            '-ut${_fmtTime(h)}',
            '-p0',
            '-house$lon,$lat,$hsysChar',
            '-fl',
            '-head',
            '-emos',
          ]);
          final lines = output
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();

          // Skip planet line (Sun), read 12 cusps, then 8 ascmc
          final cusps = <double>[];
          for (var i = 1; i <= 12; i++) {
            cusps.add(double.parse(lines[i]));
          }
          final ascmc = <double>[];
          for (var i = 13; i <= 20; i++) {
            ascmc.add(double.parse(lines[i]));
          }

          results.add({
            'date': {'year': y, 'month': m, 'day': d, 'hour': h},
            'jd': jd,
            'location': {'lat': lat, 'lon': lon, 'name': locName},
            'hsys_char': hsysChar,
            'hsys_code': hsysCode,
            'hsys_name': hsysName,
            'cusps': cusps,
            'ascmc': ascmc,
          });
        } catch (e) {
          results.add({
            'date': {'year': y, 'month': m, 'day': d, 'hour': h},
            'jd': jd,
            'location': {'lat': lat, 'lon': lon, 'name': locName},
            'hsys_char': hsysChar,
            'hsys_name': hsysName,
            'error': e.toString(),
          });
        }
      }
    }
  }
  return results;
}

/// 7. House system names — deterministic string lookups from C library.
List<Map<String, dynamic>> _generateHouseNames() {
  const names = {
    'P': 'Placidus',
    'K': 'Koch',
    'O': 'Porphyry',
    'R': 'Regiomontanus',
    'C': 'Campanus',
    'E': 'equal',
    'W': 'equal/ whole sign',
    'B': 'Alcabitius',
    'T': 'Polich/Page',
    'X': 'axial rotation system/Meridian houses',
    'M': 'Morinus',
  };
  return [
    for (final (hsysChar, hsysCode, _) in _houseSystems)
      {
        'char': hsysChar,
        'code': hsysCode,
        'swe_name': names[hsysChar]!,
      },
  ];
}

/// 8. Planet names — from swetest -fP output.
///
/// For asteroids (e.g. Chiron), swetest may print error messages about
/// missing .se1 files before the actual name. We take only the last
/// non-empty line as the planet name.
Future<List<Map<String, dynamic>>> _generatePlanetNames() async {
  final results = <Map<String, dynamic>>[];
  for (final (pid, pcode, _) in _planets) {
    // Use Process.run directly to avoid _run()'s exit code check,
    // since swetest may print warnings but still output the name.
    final result = await Process.run(_sweetestPath, [
      '-b1.1.2000',
      '-ut0',
      '-p$pcode',
      '-fP',
      '-head',
      '-emos',
    ]);
    final output = (result.stdout as String).trim();
    // Take last non-empty line (skip any error/warning lines)
    final lines = output
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final name = lines.isNotEmpty ? lines.last : output;
    results.add({
      'id': pid,
      'swe_name': name,
    });
  }
  return results;
}

/// 9. Rise/set times
Future<List<Map<String, dynamic>>> _generateRiseSet() async {
  final results = <Map<String, dynamic>>[];
  const riseDates = [
    (2000, 1, 1, 0.0),
    (2024, 3, 20, 0.0),
  ];

  for (final (y, m, d, h) in riseDates) {
    final jd = _julday(y, m, d, h);
    for (final (lat, lon, alt, locName) in _locations.take(4)) {
      for (final (pid, pcode, pname) in [
        (0, '0', 'Sun'),
        (1, '1', 'Moon'),
      ]) {
        try {
          final output = await _run([
            '-b${_fmtDate(y, m, d)}',
            '-ut${_fmtTime(h)}',
            '-p$pcode',
            '-rise',
            '-geopos$lon,$lat,$alt',
            '-head',
            '-emos',
          ]);
          // Parse: "rise      D.M.Y\t  HH:MM:SS.S    set       D.M.Y\t  HH:MM:SS.S ..."
          final riseMatch = RegExp(
            r'\brise\s+(\d+)\.(\d+)\.(-?\d+)\s+(\d+):(\d+):([\d.]+)',
          ).firstMatch(output);
          final setMatch = RegExp(
            r'\bset\s+(\d+)\.(\d+)\.(-?\d+)\s+(\d+):(\d+):([\d.]+)',
          ).firstMatch(output);

          if (riseMatch != null) {
            final rDay = int.parse(riseMatch.group(1)!);
            final rMon = int.parse(riseMatch.group(2)!);
            final rYear = int.parse(riseMatch.group(3)!);
            final rHour = int.parse(riseMatch.group(4)!) +
                int.parse(riseMatch.group(5)!) / 60.0 +
                double.parse(riseMatch.group(6)!) / 3600.0;
            final riseJd = _julday(rYear, rMon, rDay, rHour);
            results.add({
              'date': {'year': y, 'month': m, 'day': d, 'hour': h},
              'jd': jd,
              'body': pid,
              'body_name': pname,
              'event': 'rise',
              'flag': 1, // SE_CALC_RISE
              'location': {
                'lat': lat,
                'lon': lon,
                'alt': alt,
                'name': locName,
              },
              'transit_jd': riseJd,
            });
          }

          if (setMatch != null) {
            final sDay = int.parse(setMatch.group(1)!);
            final sMon = int.parse(setMatch.group(2)!);
            final sYear = int.parse(setMatch.group(3)!);
            final sHour = int.parse(setMatch.group(4)!) +
                int.parse(setMatch.group(5)!) / 60.0 +
                double.parse(setMatch.group(6)!) / 3600.0;
            final setJd = _julday(sYear, sMon, sDay, sHour);
            results.add({
              'date': {'year': y, 'month': m, 'day': d, 'hour': h},
              'jd': jd,
              'body': pid,
              'body_name': pname,
              'event': 'set',
              'flag': 2, // SE_CALC_SET
              'location': {
                'lat': lat,
                'lon': lon,
                'alt': alt,
                'name': locName,
              },
              'transit_jd': setJd,
            });
          }
        } catch (e) {
          results.add({
            'date': {'year': y, 'month': m, 'day': d, 'hour': h},
            'body': pid,
            'body_name': pname,
            'event': 'rise',
            'location': {'name': locName},
            'error': e.toString(),
          });
        }
      }
    }
  }
  return results;
}

/// 10. Degree normalization — pure math, same as swe_degnorm().
List<Map<String, dynamic>> _generateDegnorm() {
  const testValues = [
    0.0, 90.0, 180.0, 270.0, 359.999, 360.0,
    -10.0, -90.0, -180.0, -360.0, -720.5,
    370.0, 720.0, 1080.123, 0.001,
  ];
  return testValues.map((v) {
    // swe_degnorm: result = fmod(x, 360.0); if (result < 0) result += 360.0;
    var result = v % 360.0;
    if (result < 0) result += 360.0;
    return {'input': v, 'output': result};
  }).toList();
}

/// 11. Topocentric positions
Future<List<Map<String, dynamic>>> _generateTopocentric() async {
  final results = <Map<String, dynamic>>[];
  final jd = _julday(2000, 1, 1, 12.0);

  for (final (lat, lon, alt, locName) in _locations.take(4)) {
    for (final (pid, pcode, pname) in [
      (0, '0', 'Sun'),
      (1, '1', 'Moon'),
    ]) {
      final vals = await _runPlanet(
        2000, 1, 1, 12.0, pcode, 'lbR',
        extraArgs: ['-topo$lon,$lat,$alt'],
      );
      results.add({
        'jd': jd,
        'body': pid,
        'body_name': pname,
        'location': {'lat': lat, 'lon': lon, 'alt': alt, 'name': locName},
        'longitude': vals[0],
        'latitude': vals[1],
        'distance': vals[2],
      });
    }
  }
  return results;
}

/// 12. Equatorial coordinates
///
/// swetest -fadR outputs RA (decimal degrees), Dec (decimal degrees), distance.
Future<List<Map<String, dynamic>>> _generateEquatorial() async {
  final results = <Map<String, dynamic>>[];
  final jd = _julday(2000, 1, 1, 0.0);

  // Classical planets (first 7)
  for (final (pid, pcode, pname) in _planets.take(7)) {
    final vals = await _runPlanet(2000, 1, 1, 0.0, pcode, 'adR');
    results.add({
      'jd': jd,
      'body': pid,
      'body_name': pname,
      'right_ascension': vals[0],
      'declination': vals[1],
      'distance': vals[2],
    });
  }
  return results;
}

/// 13. getAyanamsaExUt — test with various flag combinations
Future<List<Map<String, dynamic>>> _generateAyanamsaEx() async {
  final results = <Map<String, dynamic>>[];
  // Test getAyanamsaExUt with a few representative ayanamsas and dates.
  // swetest -pb -fl -sidN gives the same value as swe_get_ayanamsa_ut,
  // which is what getAyanamsaExUt returns (with additional flag info).
  // We use the same swetest command; the Dart test will call getAyanamsaExUt
  // and verify it matches.
  const testCases = [
    (2000, 1, 1, 0.0, 1), // Lahiri at J2000
    (2000, 1, 1, 12.0, 0), // Fagan-Bradley at J2000 noon
    (2024, 3, 20, 12.0, 1), // Lahiri at 2024 equinox
    (2024, 3, 20, 12.0, 27), // True Citra at 2024 equinox
  ];

  for (final (y, m, d, h, sidId) in testCases) {
    final jd = _julday(y, m, d, h);
    final output = await _run([
      '-b${_fmtDate(y, m, d)}',
      '-ut${_fmtTime(h)}',
      '-pb',
      '-fl',
      '-head',
      '-emos',
      '-sid$sidId',
    ]);
    final value = double.parse(output.trim());
    results.add({
      'jd': jd,
      'ayanamsa_id': sidId,
      'value': value,
      'flags': 4 | 256, // MOSEPH | SPEED
    });
  }
  return results;
}

/// 14. Version — swetest outputs version in its banner.
Future<String> _getSweetestVersion() async {
  // Some swetest builds exit non-zero for -h, so don't use _run().
  final result = await Process.run(_sweetestPath, ['-h']);
  final output = '${result.stdout}${result.stderr}';
  final match = RegExp(r'Version:\s*([\d.]+)').firstMatch(output);
  return match?.group(1) ?? 'unknown';
}

// ── Main ────────────────────────────────────────────────────────────────────

Future<void> main(List<String> args) async {
  _sweetestPath = args.isNotEmpty ? args[0] : '../../swisseph/bin/swetest';

  // Verify swetest exists
  final sweetestFile = File(_sweetestPath);
  if (!sweetestFile.existsSync()) {
    stderr.writeln('swetest not found at $_sweetestPath');
    stderr.writeln('Usage: dart run generate_reference.dart [swetest_path]');
    exit(1);
  }

  final version = await _getSweetestVersion();
  stderr.writeln('Using swetest version $version at $_sweetestPath');

  final data = <String, dynamic>{
    '_meta': {
      'generator': 'generate_reference.dart',
      'swetest_version': version,
      'swetest_path': sweetestFile.absolute.path,
      'ephemeris': 'Moshier (no .se1 files)',
      'description':
          'Reference values from swetest for cross-validation '
          'with swisseph.dart FFI bindings.',
    },
  };

  stderr.write('Generating julday...');
  data['julday'] = await _generateJulday();
  stderr.writeln(' ${(data['julday'] as List).length} entries');

  stderr.write('Generating planet positions (Moshier)...');
  data['planet_positions_moshier'] = await _generatePlanetPositions();
  stderr.writeln(
      ' ${(data['planet_positions_moshier'] as List).length} entries');

  stderr.write('Generating sidereal positions...');
  data['sidereal_positions'] = await _generateSiderealPositions();
  stderr.writeln(' ${(data['sidereal_positions'] as List).length} entries');

  stderr.write('Generating ayanamsa values...');
  data['ayanamsa_values'] = await _generateAyanamsaValues();
  stderr.writeln(' ${(data['ayanamsa_values'] as List).length} entries');

  stderr.write('Generating ayanamsa names...');
  data['ayanamsa_names'] = _generateAyanamsaNames();
  stderr.writeln(' ${(data['ayanamsa_names'] as List).length} entries');

  stderr.write('Generating house cusps...');
  data['house_cusps'] = await _generateHouseCusps();
  stderr.writeln(' ${(data['house_cusps'] as List).length} entries');

  stderr.write('Generating house names...');
  data['house_names'] = _generateHouseNames();
  stderr.writeln(' ${(data['house_names'] as List).length} entries');

  stderr.write('Generating planet names...');
  data['planet_names'] = await _generatePlanetNames();
  stderr.writeln(' ${(data['planet_names'] as List).length} entries');

  stderr.write('Generating rise/set times...');
  data['rise_set'] = await _generateRiseSet();
  stderr.writeln(' ${(data['rise_set'] as List).length} entries');

  stderr.write('Generating degnorm...');
  data['degnorm'] = _generateDegnorm();
  stderr.writeln(' ${(data['degnorm'] as List).length} entries');

  stderr.write('Generating topocentric...');
  data['topocentric'] = await _generateTopocentric();
  stderr.writeln(' ${(data['topocentric'] as List).length} entries');

  stderr.write('Generating equatorial...');
  data['equatorial'] = await _generateEquatorial();
  stderr.writeln(' ${(data['equatorial'] as List).length} entries');

  stderr.write('Generating ayanamsa_ex...');
  data['ayanamsa_ex'] = await _generateAyanamsaEx();
  stderr.writeln(' ${(data['ayanamsa_ex'] as List).length} entries');

  // Write output
  final outputPath = 'test/swetest-validation/reference_data.json';
  final outputFile = File(outputPath);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(data),
  );

  // Print summary
  var total = 0;
  for (final entry in data.entries) {
    if (entry.key.startsWith('_')) continue;
    final count = (entry.value as List).length;
    total += count;
    stderr.writeln('  ${entry.key}: $count entries');
  }
  stderr.writeln('  TOTAL: $total reference values');
  stderr.writeln('Written to $outputPath');
}
