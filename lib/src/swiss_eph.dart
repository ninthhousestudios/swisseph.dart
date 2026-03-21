import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart' as pkg_ffi;

import 'bindings.dart';
import 'types.dart';
import 'constants.dart';

/// An instance of the Swiss Ephemeris C library.
///
/// Each instance wraps its own [ffi.DynamicLibrary] and thus its own
/// C global state. For isolate safety, load from unique .so paths —
/// `dlopen` deduplicates by device+inode, so the same file path means
/// shared globals across isolates. Copy the .so to a unique path per isolate.
///
/// **Warning: Global state drifts across await points.** Even with unique
/// .so copies, always re-set configuration (setSidMode, setEphePath, setTopo)
/// immediately before each calculation batch. Do NOT assume state set before
/// an `await` will persist after it.
///
/// Usage:
/// ```dart
/// final swe = SwissEph.find();
/// swe.setEphePath('/path/to/ephe');
/// final jd = swe.julday(2000, 1, 1, 12.0);
/// final result = swe.calcUt(jd, seSun, seflgSwieph | seflgSpeed);
/// print(result.longitude);
/// swe.close();
/// ```
class SwissEph {
  late final ffi.DynamicLibrary _lib;
  late final SweBindings _bind;

  /// Load the Swiss Ephemeris library.
  ///
  /// [libraryPath] is the path to the compiled shared library (.so/.dylib/.dll).
  SwissEph(String libraryPath) {
    _lib = ffi.DynamicLibrary.open(libraryPath);
    _bind = SweBindings(_lib);
  }

  /// Search for the built library in common locations and load it.
  ///
  /// Looks in: .dart_tool/ (build hook output).
  /// Throws [StateError] if not found.
  factory SwissEph.find() {
    final path = findLibrary();
    return SwissEph(path);
  }

  /// Search for the compiled Swiss Ephemeris shared library.
  ///
  /// Searches .dart_tool/ recursively for libswisseph.so or libswisseph.dylib.
  /// Returns the absolute path. Throws [StateError] if not found.
  static String findLibrary() {
    final dartTool = Directory('.dart_tool');
    if (dartTool.existsSync()) {
      for (final entity in dartTool.listSync(recursive: true)) {
        if (entity is File &&
            (entity.path.endsWith('libswisseph.so') ||
             entity.path.endsWith('libswisseph.dylib') ||
             entity.path.endsWith('swisseph.dll'))) {
          return entity.path;
        }
      }
    }
    throw StateError(
      'libswisseph not found. Run "dart pub get" to trigger the build hook, '
      'or pass an explicit path to SwissEph().',
    );
  }

  /// Close the library and free C-side resources.
  void close() {
    _bind.swe_close();
  }

  /// Get the Swiss Ephemeris library version string.
  String version() {
    final buf = pkg_ffi.calloc<ffi.Char>(256);
    try {
      _bind.swe_version(buf);
      return buf.cast<pkg_ffi.Utf8>().toDartString();
    } finally {
      pkg_ffi.calloc.free(buf);
    }
  }

  // --- Date/time ---

  /// Convert a calendar date to Julian Day number.
  ///
  /// [year], [month], [day] as integers; [hour] as decimal hours (e.g. 12.5 = 12:30).
  /// [gregorian] selects Gregorian (true, default) or Julian (false) calendar.
  double julday(int year, int month, int day, double hour,
      {bool gregorian = true}) {
    return _bind.swe_julday(
        year, month, day, hour, gregorian ? seGregCal : seJulCal);
  }

  /// Convert a Julian Day number back to a calendar date.
  DateResult revjul(double jd, {bool gregorian = true}) {
    final pYear = pkg_ffi.calloc<ffi.Int32>();
    final pMonth = pkg_ffi.calloc<ffi.Int32>();
    final pDay = pkg_ffi.calloc<ffi.Int32>();
    final pHour = pkg_ffi.calloc<ffi.Double>();
    try {
      _bind.swe_revjul(
          jd, gregorian ? seGregCal : seJulCal, pYear, pMonth, pDay, pHour);
      return DateResult(
        year: pYear.value,
        month: pMonth.value,
        day: pDay.value,
        hour: pHour.value,
      );
    } finally {
      pkg_ffi.calloc.free(pYear);
      pkg_ffi.calloc.free(pMonth);
      pkg_ffi.calloc.free(pDay);
      pkg_ffi.calloc.free(pHour);
    }
  }
}
