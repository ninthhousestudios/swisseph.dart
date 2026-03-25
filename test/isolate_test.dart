import 'dart:io';
import 'dart:isolate';
import 'package:test/test.dart';
import 'package:swisseph/swisseph.dart';

/// Find the built .so path.
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
    test('different sidereal modes produce different results in parallel',
        () async {
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
            reason:
                'Lahiri and Raman should give different sidereal longitudes');
      } finally {
        File(lahiriPath).deleteSync();
        File(ramanPath).deleteSync();
      }
    });

    test('shared .so path causes state contamination', () async {
      // This test documents the PROBLEM: same .so path = shared global state.
      final sharedPath = _copyLibForIsolate(baseLibPath, 99);

      try {
        // Both use same path — they'll share C state
        final results = await Future.wait([
          _calcInIsolate(sharedPath, seSidmLahiri),
          _calcInIsolate(sharedPath, seSidmRaman),
        ]);

        // With shared state, results MAY be identical (race condition)
        // We just verify both returned valid values.
        expect(results[0], greaterThan(0));
        expect(results[1], greaterThan(0));
      } finally {
        File(sharedPath).deleteSync();
      }
    });
  });
}
