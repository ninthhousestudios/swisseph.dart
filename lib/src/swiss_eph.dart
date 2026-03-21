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

  // --- Configuration ---

  /// Set the directory path for Swiss Ephemeris data files (.se1).
  void setEphePath(String path) {
    final pPath = path.toNativeUtf8(allocator: pkg_ffi.calloc).cast<ffi.Char>();
    try {
      _bind.swe_set_ephe_path(pPath);
    } finally {
      pkg_ffi.calloc.free(pPath);
    }
  }

  /// Set the sidereal mode (ayanamsa).
  void setSidMode(int sidMode, {double t0 = 0, double ayanT0 = 0}) {
    _bind.swe_set_sid_mode(sidMode, t0, ayanT0);
  }

  /// Set the geographic position for topocentric calculations.
  void setTopo(double geolon, double geolat, double geoalt) {
    _bind.swe_set_topo(geolon, geolat, geoalt);
  }

  // --- Calculations ---

  /// Calculate the position of a celestial body at a given Julian Day (UT).
  CalcResult calcUt(double jdUt, int body, int flags) {
    final xx = pkg_ffi.calloc<ffi.Double>(6);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_calc_ut(jdUt, body, flags, xx, serr);
      if (ret < 0) {
        final msg = serr.cast<pkg_ffi.Utf8>().toDartString();
        throw SweException(msg, ret);
      }
      return CalcResult(
        longitude: xx[0],
        latitude: xx[1],
        distance: xx[2],
        longitudeSpeed: xx[3],
        latitudeSpeed: xx[4],
        distanceSpeed: xx[5],
        returnFlag: ret,
      );
    } finally {
      pkg_ffi.calloc.free(xx);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Calculate house cusps for a given time and location.
  HouseResult houses(double jdUt, double geolat, double geolon, int hsys) {
    final pCusps = pkg_ffi.calloc<ffi.Double>(37);
    final pAscmc = pkg_ffi.calloc<ffi.Double>(10);
    try {
      final ret = _bind.swe_houses(jdUt, geolat, geolon, hsys, pCusps, pAscmc);
      final cusps = List<double>.generate(13, (i) => pCusps[i]);
      final ascmc = List<double>.generate(10, (i) => pAscmc[i]);
      return HouseResult(cusps: cusps, ascmc: ascmc, returnFlag: ret);
    } finally {
      pkg_ffi.calloc.free(pCusps);
      pkg_ffi.calloc.free(pAscmc);
    }
  }

  // --- Ayanamsa ---

  /// Get the ayanamsa value for a given Julian Day (UT).
  double getAyanamsaUt(double jdUt) {
    return _bind.swe_get_ayanamsa_ut(jdUt);
  }

  /// Get the ayanamsa value with extended flags.
  AyanamsaResult getAyanamsaExUt(double jdUt, int flags) {
    final pAya = pkg_ffi.calloc<ffi.Double>();
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_get_ayanamsa_ex_ut(jdUt, flags, pAya, serr);
      if (ret < 0) {
        final msg = serr.cast<pkg_ffi.Utf8>().toDartString();
        throw SweException(msg, ret);
      }
      return AyanamsaResult(ayanamsa: pAya.value, returnFlag: ret);
    } finally {
      pkg_ffi.calloc.free(pAya);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Get the name of an ayanamsa mode.
  String getAyanamsaName(int sidMode) {
    final ptr = _bind.swe_get_ayanamsa_name(sidMode);
    return ptr.cast<pkg_ffi.Utf8>().toDartString();
  }

  // --- Names ---

  /// Get the name of a celestial body.
  String getPlanetName(int body) {
    final buf = pkg_ffi.calloc<ffi.Char>(256);
    try {
      _bind.swe_get_planet_name(body, buf);
      return buf.cast<pkg_ffi.Utf8>().toDartString();
    } finally {
      pkg_ffi.calloc.free(buf);
    }
  }

  /// Get the name of a house system.
  String houseName(int hsys) {
    final ptr = _bind.swe_house_name(hsys);
    return ptr.cast<pkg_ffi.Utf8>().toDartString();
  }

  // --- Utilities ---

  /// Normalize a degree value to 0–360 range.
  double degnorm(double x) {
    return _bind.swe_degnorm(x);
  }

  // --- Rise/Set ---

  /// Find the next rise, set, or transit of a celestial body.
  RiseTransResult riseTrans(
    double jdUt,
    int body, {
    int epheflag = seflgMoseph,
    int rsmi = seCalcRise,
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
  }) {
    final geopos = pkg_ffi.calloc<ffi.Double>(3);
    final tret = pkg_ffi.calloc<ffi.Double>(10);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    final starname = pkg_ffi.calloc<ffi.Char>(256); // empty for planets
    try {
      geopos[0] = geolon;
      geopos[1] = geolat;
      geopos[2] = geoalt;

      final ret = _bind.swe_rise_trans(
          jdUt, body, starname, epheflag, rsmi, geopos, atpress, attemp,
          tret, serr);
      if (ret < 0) {
        final msg = serr.cast<pkg_ffi.Utf8>().toDartString();
        throw SweException(msg, ret);
      }
      return RiseTransResult(transitTime: tret[0], returnFlag: ret);
    } finally {
      pkg_ffi.calloc.free(geopos);
      pkg_ffi.calloc.free(tret);
      pkg_ffi.calloc.free(serr);
      pkg_ffi.calloc.free(starname);
    }
  }
}
