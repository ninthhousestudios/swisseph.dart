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
/// final result = swe.calcUt(jd, seSun, seFlgSwiEph | seFlgSpeed);
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

  /// Convert a UTC date/time to Julian Day numbers (ET and UT1).
  ///
  /// Returns a [JulianDayPair] with both Ephemeris Time and Universal Time JDs.
  /// Throws [SweException] if the date is invalid.
  JulianDayPair utcToJd(int year, int month, int day, int hour, int min,
      double sec,
      {bool gregorian = true}) {
    final dret = pkg_ffi.calloc<ffi.Double>(2);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_utc_to_jd(
          year, month, day, hour, min, sec,
          gregorian ? seGregCal : seJulCal, dret, serr);
      if (ret < 0) {
        final msg = serr.cast<pkg_ffi.Utf8>().toDartString();
        throw SweException(msg, ret);
      }
      return JulianDayPair(et: dret[0], ut1: dret[1]);
    } finally {
      pkg_ffi.calloc.free(dret);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Convert a Julian Day (UT1) to UTC date/time.
  DateTimeResult jdToUtc(double jdUt, {bool gregorian = true}) {
    final pYear = pkg_ffi.calloc<ffi.Int32>();
    final pMonth = pkg_ffi.calloc<ffi.Int32>();
    final pDay = pkg_ffi.calloc<ffi.Int32>();
    final pHour = pkg_ffi.calloc<ffi.Int32>();
    final pMin = pkg_ffi.calloc<ffi.Int32>();
    final pSec = pkg_ffi.calloc<ffi.Double>();
    try {
      _bind.swe_jdut1_to_utc(
          jdUt, gregorian ? seGregCal : seJulCal,
          pYear, pMonth, pDay, pHour, pMin, pSec);
      return DateTimeResult(
        year: pYear.value,
        month: pMonth.value,
        day: pDay.value,
        hour: pHour.value,
        min: pMin.value,
        sec: pSec.value,
      );
    } finally {
      pkg_ffi.calloc.free(pYear);
      pkg_ffi.calloc.free(pMonth);
      pkg_ffi.calloc.free(pDay);
      pkg_ffi.calloc.free(pHour);
      pkg_ffi.calloc.free(pMin);
      pkg_ffi.calloc.free(pSec);
    }
  }

  /// Convert a Julian Day (ET) to UTC date/time.
  DateTimeResult jdetToUtc(double jdEt, {bool gregorian = true}) {
    final pYear = pkg_ffi.calloc<ffi.Int32>();
    final pMonth = pkg_ffi.calloc<ffi.Int32>();
    final pDay = pkg_ffi.calloc<ffi.Int32>();
    final pHour = pkg_ffi.calloc<ffi.Int32>();
    final pMin = pkg_ffi.calloc<ffi.Int32>();
    final pSec = pkg_ffi.calloc<ffi.Double>();
    try {
      _bind.swe_jdet_to_utc(
          jdEt, gregorian ? seGregCal : seJulCal,
          pYear, pMonth, pDay, pHour, pMin, pSec);
      return DateTimeResult(
        year: pYear.value,
        month: pMonth.value,
        day: pDay.value,
        hour: pHour.value,
        min: pMin.value,
        sec: pSec.value,
      );
    } finally {
      pkg_ffi.calloc.free(pYear);
      pkg_ffi.calloc.free(pMonth);
      pkg_ffi.calloc.free(pDay);
      pkg_ffi.calloc.free(pHour);
      pkg_ffi.calloc.free(pMin);
      pkg_ffi.calloc.free(pSec);
    }
  }

  /// Convert a date/time from one timezone to UTC.
  ///
  /// [timezone] is the offset in hours (e.g. 5.5 for IST, -5 for EST).
  /// The input date/time is in the given timezone; the output is UTC.
  DateTimeResult utcTimeZone(int year, int month, int day, int hour, int min,
      double sec, double timezone) {
    final pYear = pkg_ffi.calloc<ffi.Int32>();
    final pMonth = pkg_ffi.calloc<ffi.Int32>();
    final pDay = pkg_ffi.calloc<ffi.Int32>();
    final pHour = pkg_ffi.calloc<ffi.Int32>();
    final pMin = pkg_ffi.calloc<ffi.Int32>();
    final pSec = pkg_ffi.calloc<ffi.Double>();
    try {
      _bind.swe_utc_time_zone(
          year, month, day, hour, min, sec, timezone,
          pYear, pMonth, pDay, pHour, pMin, pSec);
      return DateTimeResult(
        year: pYear.value,
        month: pMonth.value,
        day: pDay.value,
        hour: pHour.value,
        min: pMin.value,
        sec: pSec.value,
      );
    } finally {
      pkg_ffi.calloc.free(pYear);
      pkg_ffi.calloc.free(pMonth);
      pkg_ffi.calloc.free(pDay);
      pkg_ffi.calloc.free(pHour);
      pkg_ffi.calloc.free(pMin);
      pkg_ffi.calloc.free(pSec);
    }
  }

  /// Validate a date and convert to Julian Day.
  ///
  /// Returns the Julian Day number if the date is valid, or `null` if invalid
  /// (e.g. February 30).
  double? dateConversion(int year, int month, int day, double hour,
      {bool gregorian = true}) {
    final pJd = pkg_ffi.calloc<ffi.Double>();
    try {
      final ret = _bind.swe_date_conversion(
          year, month, day, hour,
          gregorian ? 0x67 : 0x6A, // 'g' or 'j'
          pJd);
      if (ret < 0) return null;
      return pJd.value;
    } finally {
      pkg_ffi.calloc.free(pJd);
    }
  }

  /// Get the day of week for a Julian Day number.
  ///
  /// Returns 0=Monday, 1=Tuesday, ..., 6=Sunday.
  int dayOfWeek(double jd) {
    return _bind.swe_day_of_week(jd);
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

  /// Set the JPL ephemeris file name (e.g. 'de431.eph').
  void setJplFile(String filename) {
    final pName =
        filename.toNativeUtf8(allocator: pkg_ffi.calloc).cast<ffi.Char>();
    try {
      _bind.swe_set_jpl_file(pName);
    } finally {
      pkg_ffi.calloc.free(pName);
    }
  }

  /// Get the file path of the Swiss Ephemeris library.
  String getLibraryPath() {
    final buf = pkg_ffi.calloc<ffi.Char>(256);
    try {
      _bind.swe_get_library_path(buf);
      return buf.cast<pkg_ffi.Utf8>().toDartString();
    } finally {
      pkg_ffi.calloc.free(buf);
    }
  }

  /// Get data about a currently loaded ephemeris file.
  ///
  /// [fileNum]: 0 = planet file (e.g. seas_18.se1), 1 = Moon file, 2 = main asteroid file.
  /// Returns [FileDataResult] with the file path (null if no file loaded),
  /// start/end dates, and ephemeris number.
  FileDataResult getCurrentFileData(int fileNum) {
    final pStart = pkg_ffi.calloc<ffi.Double>();
    final pEnd = pkg_ffi.calloc<ffi.Double>();
    final pDenum = pkg_ffi.calloc<ffi.Int32>();
    try {
      final ptr = _bind.swe_get_current_file_data(fileNum, pStart, pEnd, pDenum);
      String? path;
      if (ptr.address != 0) {
        final s = ptr.cast<pkg_ffi.Utf8>().toDartString();
        if (s.isNotEmpty) path = s;
      }
      return FileDataResult(
        path: path,
        startDate: pStart.value,
        endDate: pEnd.value,
        ephemerisNumber: pDenum.value,
      );
    } finally {
      pkg_ffi.calloc.free(pStart);
      pkg_ffi.calloc.free(pEnd);
      pkg_ffi.calloc.free(pDenum);
    }
  }

  /// Enable or disable interpolation of nutation.
  void setInterpolateNut(bool doInterpolate) {
    _bind.swe_set_interpolate_nut(doInterpolate ? 1 : 0);
  }

  /// Set the lapse rate for refraction calculations.
  void setLapseRate(double lapseRate) {
    _bind.swe_set_lapse_rate(lapseRate);
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

  /// Calculate the position of a celestial body at a given Julian Day (ET).
  ///
  /// Unlike [calcUt], this takes Ephemeris Time (ET/TDB) rather than UT.
  CalcResult calc(double jdEt, int body, int flags) {
    final xx = pkg_ffi.calloc<ffi.Double>(6);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_calc(jdEt, body, flags, xx, serr);
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
      if (ret < 0) {
        throw SweException('House calculation failed', ret);
      }
      final cuspCount = hsys == 0x47 ? 37 : 13; // 'G' = Gauquelin sectors
      final cusps = List<double>.generate(cuspCount, (i) => pCusps[i]);
      final ascmc = List<double>.generate(10, (i) => pAscmc[i]);
      return HouseResult(cusps: cusps, ascmc: ascmc, returnFlag: ret);
    } finally {
      pkg_ffi.calloc.free(pCusps);
      pkg_ffi.calloc.free(pAscmc);
    }
  }

  /// Calculate house cusps with flags (e.g. sidereal).
  ///
  /// Like [houses], but accepts [flags] for sidereal mode etc.
  HouseResult housesEx(double jdUt, int flags, double geolat, double geolon,
      int hsys) {
    final pCusps = pkg_ffi.calloc<ffi.Double>(37);
    final pAscmc = pkg_ffi.calloc<ffi.Double>(10);
    try {
      final ret =
          _bind.swe_houses_ex(jdUt, flags, geolat, geolon, hsys, pCusps, pAscmc);
      if (ret < 0) {
        throw SweException('House calculation failed', ret);
      }
      final cuspCount = hsys == 0x47 ? 37 : 13; // 'G' = Gauquelin sectors
      final cusps = List<double>.generate(cuspCount, (i) => pCusps[i]);
      final ascmc = List<double>.generate(10, (i) => pAscmc[i]);
      return HouseResult(cusps: cusps, ascmc: ascmc, returnFlag: ret);
    } finally {
      pkg_ffi.calloc.free(pCusps);
      pkg_ffi.calloc.free(pAscmc);
    }
  }

  /// Calculate house cusps with speeds.
  ///
  /// Returns [HouseResultEx] which includes cusp and ascmc speeds.
  HouseResultEx housesEx2(double jdUt, int flags, double geolat, double geolon,
      int hsys) {
    final pCusps = pkg_ffi.calloc<ffi.Double>(37);
    final pAscmc = pkg_ffi.calloc<ffi.Double>(10);
    final pCuspSpeed = pkg_ffi.calloc<ffi.Double>(37);
    final pAscmcSpeed = pkg_ffi.calloc<ffi.Double>(10);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_houses_ex2(
          jdUt, flags, geolat, geolon, hsys,
          pCusps, pAscmc, pCuspSpeed, pAscmcSpeed, serr);
      if (ret < 0) {
        final msg = serr.cast<pkg_ffi.Utf8>().toDartString();
        throw SweException(msg, ret);
      }
      final cuspCount = hsys == 0x47 ? 37 : 13; // 'G' = Gauquelin sectors
      final cusps = List<double>.generate(cuspCount, (i) => pCusps[i]);
      final ascmc = List<double>.generate(10, (i) => pAscmc[i]);
      final cuspSpeeds = List<double>.generate(cuspCount, (i) => pCuspSpeed[i]);
      final ascmcSpeeds = List<double>.generate(10, (i) => pAscmcSpeed[i]);
      return HouseResultEx(
        cusps: cusps,
        ascmc: ascmc,
        cuspSpeeds: cuspSpeeds,
        ascmcSpeeds: ascmcSpeeds,
        returnFlag: ret,
      );
    } finally {
      pkg_ffi.calloc.free(pCusps);
      pkg_ffi.calloc.free(pAscmc);
      pkg_ffi.calloc.free(pCuspSpeed);
      pkg_ffi.calloc.free(pAscmcSpeed);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Calculate house cusps from ARMC.
  ///
  /// [armc] is the right ascension of the MC, [geolat] is geographic latitude,
  /// [eps] is the obliquity of the ecliptic.
  HouseResult housesArmc(double armc, double geolat, double eps, int hsys) {
    final pCusps = pkg_ffi.calloc<ffi.Double>(37);
    final pAscmc = pkg_ffi.calloc<ffi.Double>(10);
    try {
      final ret =
          _bind.swe_houses_armc(armc, geolat, eps, hsys, pCusps, pAscmc);
      if (ret < 0) {
        throw SweException('House calculation failed', ret);
      }
      final cuspCount = hsys == 0x47 ? 37 : 13; // 'G' = Gauquelin sectors
      final cusps = List<double>.generate(cuspCount, (i) => pCusps[i]);
      final ascmc = List<double>.generate(10, (i) => pAscmc[i]);
      return HouseResult(cusps: cusps, ascmc: ascmc, returnFlag: ret);
    } finally {
      pkg_ffi.calloc.free(pCusps);
      pkg_ffi.calloc.free(pAscmc);
    }
  }

  /// Calculate house cusps from ARMC with speeds.
  ///
  /// Like [housesArmc], but returns [HouseResultEx] with cusp and ascmc speeds.
  HouseResultEx housesArmcEx2(
      double armc, double geolat, double eps, int hsys) {
    final pCusps = pkg_ffi.calloc<ffi.Double>(37);
    final pAscmc = pkg_ffi.calloc<ffi.Double>(10);
    final pCuspSpeed = pkg_ffi.calloc<ffi.Double>(37);
    final pAscmcSpeed = pkg_ffi.calloc<ffi.Double>(10);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_houses_armc_ex2(
          armc, geolat, eps, hsys,
          pCusps, pAscmc, pCuspSpeed, pAscmcSpeed, serr);
      if (ret < 0) {
        final msg = serr.cast<pkg_ffi.Utf8>().toDartString();
        throw SweException(msg, ret);
      }
      final cuspCount = hsys == 0x47 ? 37 : 13; // 'G' = Gauquelin sectors
      final cusps = List<double>.generate(cuspCount, (i) => pCusps[i]);
      final ascmc = List<double>.generate(10, (i) => pAscmc[i]);
      final cuspSpeeds = List<double>.generate(cuspCount, (i) => pCuspSpeed[i]);
      final ascmcSpeeds = List<double>.generate(10, (i) => pAscmcSpeed[i]);
      return HouseResultEx(
        cusps: cusps,
        ascmc: ascmc,
        cuspSpeeds: cuspSpeeds,
        ascmcSpeeds: ascmcSpeeds,
        returnFlag: ret,
      );
    } finally {
      pkg_ffi.calloc.free(pCusps);
      pkg_ffi.calloc.free(pAscmc);
      pkg_ffi.calloc.free(pCuspSpeed);
      pkg_ffi.calloc.free(pAscmcSpeed);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Determine the house position of a body.
  ///
  /// Returns a double between 1.0 and 12.999... indicating the house position.
  /// [armc] is the right ascension of the MC, [geolat] is geographic latitude,
  /// [eps] is the obliquity of the ecliptic, [bodyLon] and [bodyLat] are the
  /// ecliptic coordinates of the body.
  double housePos(double armc, double geolat, double eps, int hsys,
      double bodyLon, double bodyLat) {
    final xpin = pkg_ffi.calloc<ffi.Double>(2);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      xpin[0] = bodyLon;
      xpin[1] = bodyLat;
      final result =
          _bind.swe_house_pos(armc, geolat, eps, hsys, xpin, serr);
      if (result == 0.0) {
        final msg = serr.cast<pkg_ffi.Utf8>().toDartString();
        throw SweException(msg.isEmpty ? 'swe_house_pos failed' : msg, 0);
      }
      return result;
    } finally {
      pkg_ffi.calloc.free(xpin);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Calculate the Gauquelin sector position of a body.
  ///
  /// Returns a sector number between 1 and 36.
  /// [method]: 0 = sector from rise/set, 1 = sector from MC/IC,
  /// 2 = with Gauquelin sector cusp, 3 = Placidus house position * 3.
  double gauquelinSector(
    double jdUt,
    int body,
    int flags,
    int method, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
    String? starName,
  }) {
    final geopos = pkg_ffi.calloc<ffi.Double>(3);
    final dgsect = pkg_ffi.calloc<ffi.Double>(1);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    final starnameBuf = pkg_ffi.calloc<ffi.Char>(256);
    try {
      if (starName != null) {
        final starBytes = starName.toNativeUtf8(allocator: pkg_ffi.calloc);
        final len = starBytes.length;
        for (int i = 0; i < len && i < 255; i++) {
          starnameBuf[i] = starBytes.cast<ffi.Uint8>()[i];
        }
        starnameBuf[len.clamp(0, 255)] = 0;
        pkg_ffi.calloc.free(starBytes);
      }
      geopos[0] = geolon;
      geopos[1] = geolat;
      geopos[2] = geoalt;

      final ret = _bind.swe_gauquelin_sector(
          jdUt, body, starnameBuf, flags, method, geopos, atpress, attemp,
          dgsect, serr);
      if (ret < 0) {
        final msg = serr.cast<pkg_ffi.Utf8>().toDartString();
        throw SweException(msg, ret);
      }
      return dgsect[0];
    } finally {
      pkg_ffi.calloc.free(geopos);
      pkg_ffi.calloc.free(dgsect);
      pkg_ffi.calloc.free(serr);
      pkg_ffi.calloc.free(starnameBuf);
    }
  }

  // --- Ayanamsa ---

  /// Get the ayanamsa value for a given Julian Day (UT).
  double getAyanamsaUt(double jdUt) {
    return _bind.swe_get_ayanamsa_ut(jdUt);
  }

  /// Get the ayanamsa value for a given Julian Day (ET).
  double getAyanamsa(double jdEt) {
    return _bind.swe_get_ayanamsa(jdEt);
  }

  /// Get the ayanamsa value with extended flags (UT).
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

  /// Get the ayanamsa value with extended flags (ET).
  AyanamsaResult getAyanamsaEx(double jdEt, int flags) {
    final pAya = pkg_ffi.calloc<ffi.Double>();
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_get_ayanamsa_ex(jdEt, flags, pAya, serr);
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

  // --- Fixed stars ---

  /// Look up a fixed star position at a given Julian Day (UT).
  ///
  /// [star] is the star name or search string (e.g. "Sirius", "Aldebaran").
  /// The returned [FixstarResult.starName] contains the resolved full name.
  FixstarResult fixstar2Ut(String star, double jdUt, int flags) {
    final starBuf = pkg_ffi.calloc<ffi.Char>(512);
    final xx = pkg_ffi.calloc<ffi.Double>(6);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final starBytes = star.toNativeUtf8(allocator: pkg_ffi.calloc);
      final len = starBytes.length;
      for (int i = 0; i < len && i < 511; i++) {
        starBuf[i] = starBytes.cast<ffi.Uint8>()[i];
      }
      starBuf[len.clamp(0, 511)] = 0;
      pkg_ffi.calloc.free(starBytes);

      final ret = _bind.swe_fixstar2_ut(starBuf, jdUt, flags, xx, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      final resolvedName = starBuf.cast<pkg_ffi.Utf8>().toDartString();
      return FixstarResult(
        starName: resolvedName,
        longitude: xx[0], latitude: xx[1], distance: xx[2],
        longitudeSpeed: xx[3], latitudeSpeed: xx[4], distanceSpeed: xx[5],
        returnFlag: ret,
      );
    } finally {
      pkg_ffi.calloc.free(starBuf);
      pkg_ffi.calloc.free(xx);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Look up a fixed star position at a given Julian Day (ET).
  ///
  /// [star] is the star name or search string (e.g. "Sirius", "Aldebaran").
  /// The returned [FixstarResult.starName] contains the resolved full name.
  FixstarResult fixstar2(String star, double jdEt, int flags) {
    final starBuf = pkg_ffi.calloc<ffi.Char>(512);
    final xx = pkg_ffi.calloc<ffi.Double>(6);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final starBytes = star.toNativeUtf8(allocator: pkg_ffi.calloc);
      final len = starBytes.length;
      for (int i = 0; i < len && i < 511; i++) {
        starBuf[i] = starBytes.cast<ffi.Uint8>()[i];
      }
      starBuf[len.clamp(0, 511)] = 0;
      pkg_ffi.calloc.free(starBytes);

      final ret = _bind.swe_fixstar2(starBuf, jdEt, flags, xx, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      final resolvedName = starBuf.cast<pkg_ffi.Utf8>().toDartString();
      return FixstarResult(
        starName: resolvedName,
        longitude: xx[0], latitude: xx[1], distance: xx[2],
        longitudeSpeed: xx[3], latitudeSpeed: xx[4], distanceSpeed: xx[5],
        returnFlag: ret,
      );
    } finally {
      pkg_ffi.calloc.free(starBuf);
      pkg_ffi.calloc.free(xx);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Get the visual magnitude of a fixed star.
  ///
  /// [star] is the star name or search string.
  double fixstar2Mag(String star) {
    final starBuf = pkg_ffi.calloc<ffi.Char>(512);
    final mag = pkg_ffi.calloc<ffi.Double>(1);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final starBytes = star.toNativeUtf8(allocator: pkg_ffi.calloc);
      final len = starBytes.length;
      for (int i = 0; i < len && i < 511; i++) {
        starBuf[i] = starBytes.cast<ffi.Uint8>()[i];
      }
      starBuf[len.clamp(0, 511)] = 0;
      pkg_ffi.calloc.free(starBytes);

      final ret = _bind.swe_fixstar2_mag(starBuf, mag, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return mag[0];
    } finally {
      pkg_ffi.calloc.free(starBuf);
      pkg_ffi.calloc.free(mag);
      pkg_ffi.calloc.free(serr);
    }
  }

  // --- Crossing functions ---

  /// Find the next Sun crossing of a given ecliptic longitude (UT).
  ///
  /// Returns the Julian Day (UT) when the Sun crosses [longitude].
  /// Search starts from [jdUt].
  double solCrossUt(double longitude, double jdUt, int flags) {
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final result = _bind.swe_solcross_ut(longitude, jdUt, flags, serr);
      if (result < jdUt) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), -1);
      }
      return result;
    } finally {
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Find the next Sun crossing of a given ecliptic longitude (ET).
  ///
  /// Returns the Julian Day (ET) when the Sun crosses [longitude].
  /// Search starts from [jdEt].
  double solCross(double longitude, double jdEt, int flags) {
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final result = _bind.swe_solcross(longitude, jdEt, flags, serr);
      if (result < jdEt) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), -1);
      }
      return result;
    } finally {
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Find the next Moon crossing of a given ecliptic longitude (UT).
  ///
  /// Returns the Julian Day (UT) when the Moon crosses [longitude].
  /// Search starts from [jdUt].
  double moonCrossUt(double longitude, double jdUt, int flags) {
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final result = _bind.swe_mooncross_ut(longitude, jdUt, flags, serr);
      if (result < jdUt) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), -1);
      }
      return result;
    } finally {
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Find the next Moon crossing of a given ecliptic longitude (ET).
  ///
  /// Returns the Julian Day (ET) when the Moon crosses [longitude].
  /// Search starts from [jdEt].
  double moonCross(double longitude, double jdEt, int flags) {
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final result = _bind.swe_mooncross(longitude, jdEt, flags, serr);
      if (result < jdEt) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), -1);
      }
      return result;
    } finally {
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Find the next Moon node crossing (UT).
  ///
  /// Returns the Julian Day and ecliptic coordinates when the Moon
  /// crosses the lunar node axis. Search starts from [jdUt].
  MoonNodeCrossResult moonCrossNodeUt(double jdUt, int flags) {
    final xlon = pkg_ffi.calloc<ffi.Double>(1);
    final xlat = pkg_ffi.calloc<ffi.Double>(1);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final result = _bind.swe_mooncross_node_ut(jdUt, flags, xlon, xlat, serr);
      if (result < jdUt) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), -1);
      }
      return MoonNodeCrossResult(
        jdUt: result,
        longitude: xlon[0],
        latitude: xlat[0],
      );
    } finally {
      pkg_ffi.calloc.free(xlon);
      pkg_ffi.calloc.free(xlat);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Find the next Moon node crossing (ET).
  ///
  /// Returns the Julian Day and ecliptic coordinates when the Moon
  /// crosses the lunar node axis. Search starts from [jdEt].
  MoonNodeCrossResult moonCrossNode(double jdEt, int flags) {
    final xlon = pkg_ffi.calloc<ffi.Double>(1);
    final xlat = pkg_ffi.calloc<ffi.Double>(1);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final result = _bind.swe_mooncross_node(jdEt, flags, xlon, xlat, serr);
      if (result < jdEt) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), -1);
      }
      return MoonNodeCrossResult(
        jdUt: result,
        longitude: xlon[0],
        latitude: xlat[0],
      );
    } finally {
      pkg_ffi.calloc.free(xlon);
      pkg_ffi.calloc.free(xlat);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Find the next heliocentric crossing of a given longitude (UT).
  ///
  /// [body] is the planet ID, [longitude] is the target ecliptic longitude,
  /// [dir] is the search direction (1 = forward, -1 = backward).
  /// Returns the Julian Day (UT) of the crossing.
  double helioCrossUt(int body, double longitude, double jdUt, int flags,
      int dir) {
    final jdCross = pkg_ffi.calloc<ffi.Double>(1);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_helio_cross_ut(
          body, longitude, jdUt, flags, dir, jdCross, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return jdCross[0];
    } finally {
      pkg_ffi.calloc.free(jdCross);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Find the next heliocentric crossing of a given longitude (ET).
  ///
  /// [body] is the planet ID, [longitude] is the target ecliptic longitude,
  /// [dir] is the search direction (1 = forward, -1 = backward).
  /// Returns the Julian Day (ET) of the crossing.
  double helioCross(int body, double longitude, double jdEt, int flags,
      int dir) {
    final jdCross = pkg_ffi.calloc<ffi.Double>(1);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_helio_cross(
          body, longitude, jdEt, flags, dir, jdCross, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return jdCross[0];
    } finally {
      pkg_ffi.calloc.free(jdCross);
      pkg_ffi.calloc.free(serr);
    }
  }

  // --- Utilities ---

  /// Normalize a degree value to 0–360 range.
  double degnorm(double x) {
    return _bind.swe_degnorm(x);
  }

  // --- Eclipses ---

  /// Find the next solar eclipse visible from a given location.
  ///
  /// [jdStart] is the Julian Day to start searching from.
  /// [flags] are ephemeris flags (e.g. seFlgMosEph).
  /// Returns timing and attributes of the eclipse at the given location.
  SolarEclipseLocalResult solEclipseWhenLoc(double jdStart, int flags,
      {required double geolon, required double geolat, double geoalt = 0,
       bool backward = false}) {
    final geopos = pkg_ffi.calloc<ffi.Double>(3);
    final tret = pkg_ffi.calloc<ffi.Double>(10);
    final attr = pkg_ffi.calloc<ffi.Double>(20);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      geopos[0] = geolon;
      geopos[1] = geolat;
      geopos[2] = geoalt;
      final ret = _bind.swe_sol_eclipse_when_loc(
          jdStart, flags, geopos, tret, attr, backward ? 1 : 0, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return SolarEclipseLocalResult(
        maxEclipse: tret[0], firstContact: tret[1], secondContact: tret[2],
        thirdContact: tret[3], fourthContact: tret[4],
        sunrise: tret[5], sunset: tret[6],
        magnitude: attr[0], diameterRatio: attr[1], obscuration: attr[2],
        coreShadowKm: attr[3], sunAzimuth: attr[4], sunTrueAltitude: attr[5],
        sunApparentAltitude: attr[6], moonSunAngle: attr[7],
        magnitudeNasa: attr[8], sarosSeries: attr[9], sarosMember: attr[10],
        returnFlag: ret,
      );
    } finally {
      pkg_ffi.calloc.free(geopos);
      pkg_ffi.calloc.free(tret);
      pkg_ffi.calloc.free(attr);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Find the next solar eclipse globally.
  ///
  /// [jdStart] is the Julian Day to start searching from.
  /// [flags] are ephemeris flags. [eclType] filters by eclipse type (0 = any).
  SolarEclipseGlobalResult solEclipseWhenGlob(double jdStart, int flags,
      {int eclType = 0, bool backward = false}) {
    final tret = pkg_ffi.calloc<ffi.Double>(10);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_sol_eclipse_when_glob(
          jdStart, flags, eclType, tret, backward ? 1 : 0, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return SolarEclipseGlobalResult(
        maxEclipse: tret[0], localNoon: tret[1],
        begin: tret[2], end: tret[3],
        totalityBegin: tret[4], totalityEnd: tret[5],
        centerLineBegin: tret[6], centerLineEnd: tret[7],
        annularTotalBegin: tret[8], annularTotalEnd: tret[9],
        returnFlag: ret,
      );
    } finally {
      pkg_ffi.calloc.free(tret);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Compute attributes of a solar eclipse at a given time and location.
  SolarEclipseAttrResult solEclipseHow(double jdUt, int flags,
      {required double geolon, required double geolat, double geoalt = 0}) {
    final geopos = pkg_ffi.calloc<ffi.Double>(3);
    final attr = pkg_ffi.calloc<ffi.Double>(20);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      geopos[0] = geolon;
      geopos[1] = geolat;
      geopos[2] = geoalt;
      final ret = _bind.swe_sol_eclipse_how(jdUt, flags, geopos, attr, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return SolarEclipseAttrResult(
        magnitude: attr[0], diameterRatio: attr[1], obscuration: attr[2],
        coreShadowKm: attr[3], sunAzimuth: attr[4], sunTrueAltitude: attr[5],
        sunApparentAltitude: attr[6], moonSunAngle: attr[7],
        magnitudeNasa: attr[8], sarosSeries: attr[9], sarosMember: attr[10],
        returnFlag: ret,
      );
    } finally {
      pkg_ffi.calloc.free(geopos);
      pkg_ffi.calloc.free(attr);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Find the geographic location of the central line of a solar eclipse.
  ///
  /// [jdUt] is the Julian Day at which to find the eclipse center.
  EclipseWhereResult solEclipseWhere(double jdUt, int flags) {
    final geopos = pkg_ffi.calloc<ffi.Double>(2);
    final attr = pkg_ffi.calloc<ffi.Double>(20);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_sol_eclipse_where(jdUt, flags, geopos, attr, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return EclipseWhereResult(
        geolon: geopos[0], geolat: geopos[1],
        magnitude: attr[0], diameterRatio: attr[1], obscuration: attr[2],
        coreShadowKm: attr[3], sunAzimuth: attr[4], sunTrueAltitude: attr[5],
        sunApparentAltitude: attr[6], moonSunAngle: attr[7],
        returnFlag: ret,
      );
    } finally {
      pkg_ffi.calloc.free(geopos);
      pkg_ffi.calloc.free(attr);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Find the next lunar eclipse globally.
  ///
  /// [jdStart] is the Julian Day to start searching from.
  /// [flags] are ephemeris flags. [eclType] filters by eclipse type (0 = any).
  LunarEclipseGlobalResult lunEclipseWhen(double jdStart, int flags,
      {int eclType = 0, bool backward = false}) {
    final tret = pkg_ffi.calloc<ffi.Double>(10);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_lun_eclipse_when(
          jdStart, flags, eclType, tret, backward ? 1 : 0, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return LunarEclipseGlobalResult(
        maxEclipse: tret[0],
        partialBegin: tret[2], partialEnd: tret[3],
        totalityBegin: tret[4], totalityEnd: tret[5],
        penumbralBegin: tret[6], penumbralEnd: tret[7],
        returnFlag: ret,
      );
    } finally {
      pkg_ffi.calloc.free(tret);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Find the next lunar eclipse visible from a given location.
  LunarEclipseLocalResult lunEclipseWhenLoc(double jdStart, int flags,
      {required double geolon, required double geolat, double geoalt = 0,
       bool backward = false}) {
    final geopos = pkg_ffi.calloc<ffi.Double>(3);
    final tret = pkg_ffi.calloc<ffi.Double>(10);
    final attr = pkg_ffi.calloc<ffi.Double>(20);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      geopos[0] = geolon;
      geopos[1] = geolat;
      geopos[2] = geoalt;
      final ret = _bind.swe_lun_eclipse_when_loc(
          jdStart, flags, geopos, tret, attr, backward ? 1 : 0, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return LunarEclipseLocalResult(
        maxEclipse: tret[0],
        partialBegin: tret[2], partialEnd: tret[3],
        totalityBegin: tret[4], totalityEnd: tret[5],
        penumbralBegin: tret[6], penumbralEnd: tret[7],
        moonrise: tret[8], moonset: tret[9],
        umbralMagnitude: attr[0], penumbralMagnitude: attr[1],
        moonAzimuth: attr[4], moonTrueAltitude: attr[5],
        moonApparentAltitude: attr[6], moonOppositionAngle: attr[7],
        sarosSeries: attr[9], sarosMember: attr[10],
        returnFlag: ret,
      );
    } finally {
      pkg_ffi.calloc.free(geopos);
      pkg_ffi.calloc.free(tret);
      pkg_ffi.calloc.free(attr);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Compute attributes of a lunar eclipse at a given time and location.
  LunarEclipseAttrResult lunEclipseHow(double jdUt, int flags,
      {required double geolon, required double geolat, double geoalt = 0}) {
    final geopos = pkg_ffi.calloc<ffi.Double>(3);
    final attr = pkg_ffi.calloc<ffi.Double>(20);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      geopos[0] = geolon;
      geopos[1] = geolat;
      geopos[2] = geoalt;
      final ret = _bind.swe_lun_eclipse_how(jdUt, flags, geopos, attr, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return LunarEclipseAttrResult(
        umbralMagnitude: attr[0], penumbralMagnitude: attr[1],
        moonAzimuth: attr[4], moonTrueAltitude: attr[5],
        moonApparentAltitude: attr[6], moonOppositionAngle: attr[7],
        sarosSeries: attr[9], sarosMember: attr[10],
        returnFlag: ret,
      );
    } finally {
      pkg_ffi.calloc.free(geopos);
      pkg_ffi.calloc.free(attr);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Find the next lunar occultation of a body visible from a given location.
  ///
  /// [body] is the planet ID. [starname] is optional for fixed star occultations.
  SolarEclipseLocalResult lunOccultWhenLoc(double jdStart, int body, int flags,
      {String? starname, required double geolon, required double geolat,
       double geoalt = 0, bool backward = false}) {
    final geopos = pkg_ffi.calloc<ffi.Double>(3);
    final tret = pkg_ffi.calloc<ffi.Double>(10);
    final attr = pkg_ffi.calloc<ffi.Double>(20);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    final starNative = starname?.toNativeUtf8(allocator: pkg_ffi.calloc);
    final starPtr = starNative?.cast<ffi.Char>() ?? ffi.nullptr.cast<ffi.Char>();
    try {
      geopos[0] = geolon;
      geopos[1] = geolat;
      geopos[2] = geoalt;
      final ret = _bind.swe_lun_occult_when_loc(
          jdStart, body, starPtr, flags, geopos, tret, attr,
          backward ? 1 : 0, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return SolarEclipseLocalResult(
        maxEclipse: tret[0], firstContact: tret[1], secondContact: tret[2],
        thirdContact: tret[3], fourthContact: tret[4],
        sunrise: tret[5], sunset: tret[6],
        magnitude: attr[0], diameterRatio: attr[1], obscuration: attr[2],
        coreShadowKm: attr[3], sunAzimuth: attr[4], sunTrueAltitude: attr[5],
        sunApparentAltitude: attr[6], moonSunAngle: attr[7],
        magnitudeNasa: attr[8], sarosSeries: attr[9], sarosMember: attr[10],
        returnFlag: ret,
      );
    } finally {
      pkg_ffi.calloc.free(geopos);
      pkg_ffi.calloc.free(tret);
      pkg_ffi.calloc.free(attr);
      pkg_ffi.calloc.free(serr);
      if (starNative != null) pkg_ffi.calloc.free(starNative);
    }
  }

  /// Find the next lunar occultation of a body globally.
  SolarEclipseGlobalResult lunOccultWhenGlob(double jdStart, int body,
      int flags,
      {String? starname, int eclType = 0, bool backward = false}) {
    final tret = pkg_ffi.calloc<ffi.Double>(10);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    final starNative = starname?.toNativeUtf8(allocator: pkg_ffi.calloc);
    final starPtr = starNative?.cast<ffi.Char>() ?? ffi.nullptr.cast<ffi.Char>();
    try {
      final ret = _bind.swe_lun_occult_when_glob(
          jdStart, body, starPtr, flags, eclType, tret,
          backward ? 1 : 0, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return SolarEclipseGlobalResult(
        maxEclipse: tret[0], localNoon: tret[1],
        begin: tret[2], end: tret[3],
        totalityBegin: tret[4], totalityEnd: tret[5],
        centerLineBegin: tret[6], centerLineEnd: tret[7],
        annularTotalBegin: tret[8], annularTotalEnd: tret[9],
        returnFlag: ret,
      );
    } finally {
      pkg_ffi.calloc.free(tret);
      pkg_ffi.calloc.free(serr);
      if (starNative != null) pkg_ffi.calloc.free(starNative);
    }
  }

  /// Find the geographic location of the central line of a lunar occultation.
  EclipseWhereResult lunOccultWhere(double jdUt, int body, int flags,
      {String? starname}) {
    final geopos = pkg_ffi.calloc<ffi.Double>(2);
    final attr = pkg_ffi.calloc<ffi.Double>(20);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    final starNative = starname?.toNativeUtf8(allocator: pkg_ffi.calloc);
    final starPtr = starNative?.cast<ffi.Char>() ?? ffi.nullptr.cast<ffi.Char>();
    try {
      final ret = _bind.swe_lun_occult_where(
          jdUt, body, starPtr, flags, geopos, attr, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return EclipseWhereResult(
        geolon: geopos[0], geolat: geopos[1],
        magnitude: attr[0], diameterRatio: attr[1], obscuration: attr[2],
        coreShadowKm: attr[3], sunAzimuth: attr[4], sunTrueAltitude: attr[5],
        sunApparentAltitude: attr[6], moonSunAngle: attr[7],
        returnFlag: ret,
      );
    } finally {
      pkg_ffi.calloc.free(geopos);
      pkg_ffi.calloc.free(attr);
      pkg_ffi.calloc.free(serr);
      if (starNative != null) pkg_ffi.calloc.free(starNative);
    }
  }

  // --- Rise/Set ---

  /// Find the next rise, set, or transit of a celestial body.
  RiseTransResult riseTrans(
    double jdUt,
    int body, {
    int epheflag = seFlgMosEph,
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

  // --- Horizon/Coordinates ---

  /// Convert ecliptic or equatorial coordinates to horizontal (azimuth/altitude).
  ///
  /// [jdUt] is the Julian Day (UT). [calcFlag] is [seEcl2hor] or [seEqu2hor].
  /// Geographic position is given by [geolon], [geolat], [geoalt].
  /// Atmospheric refraction uses [atpress] (mbar) and [attemp] (°C).
  /// Input body position is [bodyLon], [bodyLat], [bodyDist].
  AzAltResult azAlt(double jdUt, int calcFlag,
      {required double geolon, required double geolat, double geoalt = 0,
       double atpress = 1013.25, double attemp = 15.0,
       required double bodyLon, required double bodyLat, double bodyDist = 1.0}) {
    final geopos = pkg_ffi.calloc<ffi.Double>(3);
    final xin = pkg_ffi.calloc<ffi.Double>(3);
    final xaz = pkg_ffi.calloc<ffi.Double>(3);
    try {
      geopos[0] = geolon;
      geopos[1] = geolat;
      geopos[2] = geoalt;
      xin[0] = bodyLon;
      xin[1] = bodyLat;
      xin[2] = bodyDist;
      _bind.swe_azalt(jdUt, calcFlag, geopos, atpress, attemp, xin, xaz);
      return AzAltResult(
        azimuth: xaz[0],
        trueAltitude: xaz[1],
        apparentAltitude: xaz[2],
      );
    } finally {
      pkg_ffi.calloc.free(geopos);
      pkg_ffi.calloc.free(xin);
      pkg_ffi.calloc.free(xaz);
    }
  }

  /// Convert horizontal (azimuth/altitude) coordinates back to ecliptic or equatorial.
  ///
  /// [jdUt] is the Julian Day (UT). [calcFlag] is [seHor2ecl] or [seHor2equ].
  /// Geographic position is given by [geolon], [geolat], [geoalt].
  /// Input is [azimuth] and [altitude] (true altitude, not apparent).
  AzAltRevResult azAltRev(double jdUt, int calcFlag,
      {required double geolon, required double geolat, double geoalt = 0,
       required double azimuth, required double altitude}) {
    final geopos = pkg_ffi.calloc<ffi.Double>(3);
    final xin = pkg_ffi.calloc<ffi.Double>(2);
    final xout = pkg_ffi.calloc<ffi.Double>(2);
    try {
      geopos[0] = geolon;
      geopos[1] = geolat;
      geopos[2] = geoalt;
      xin[0] = azimuth;
      xin[1] = altitude;
      _bind.swe_azalt_rev(jdUt, calcFlag, geopos, xin, xout);
      return AzAltRevResult(lon: xout[0], lat: xout[1]);
    } finally {
      pkg_ffi.calloc.free(geopos);
      pkg_ffi.calloc.free(xin);
      pkg_ffi.calloc.free(xout);
    }
  }

  /// Transform between ecliptic and equatorial coordinate systems.
  ///
  /// [lon], [lat], [dist] are the input coordinates.
  /// [eps] is the obliquity of the ecliptic in degrees.
  /// To convert from ecliptic to equatorial, use positive [eps].
  /// To convert from equatorial to ecliptic, use negative [eps].
  CoTransResult cotrans(double lon, double lat, double dist, double eps) {
    final xpo = pkg_ffi.calloc<ffi.Double>(3);
    final xpn = pkg_ffi.calloc<ffi.Double>(3);
    try {
      xpo[0] = lon;
      xpo[1] = lat;
      xpo[2] = dist;
      _bind.swe_cotrans(xpo, xpn, eps);
      return CoTransResult(lon: xpn[0], lat: xpn[1], dist: xpn[2]);
    } finally {
      pkg_ffi.calloc.free(xpo);
      pkg_ffi.calloc.free(xpn);
    }
  }

  /// Apply atmospheric refraction to an altitude value.
  ///
  /// [altitude] is the input altitude in degrees.
  /// [atpress] is atmospheric pressure in mbar, [attemp] is temperature in °C.
  /// [calcFlag] is [seTrueToApp] or [seAppToTrue].
  /// Returns the refracted altitude.
  double refrac(double altitude, double atpress, double attemp, int calcFlag) {
    return _bind.swe_refrac(altitude, atpress, attemp, calcFlag);
  }

  /// Apply atmospheric refraction with extended parameters.
  ///
  /// [altitude] is the input altitude in degrees.
  /// [geoalt] is the observer altitude above sea level in meters.
  /// [atpress] is atmospheric pressure in mbar, [attemp] is temperature in °C.
  /// [lapseRate] is the lapse rate (0.0065 is standard).
  /// [calcFlag] is [seTrueToApp] or [seAppToTrue].
  RefracResult refracExtended(double altitude, double geoalt,
      double atpress, double attemp, double lapseRate, int calcFlag) {
    final dret = pkg_ffi.calloc<ffi.Double>(4);
    try {
      _bind.swe_refrac_extended(
          altitude, geoalt, atpress, attemp, lapseRate, calcFlag, dret);
      return RefracResult(
        trueAltitude: dret[0],
        apparentAltitude: dret[1],
        refraction: dret[2],
        horizonDip: dret[3],
      );
    } finally {
      pkg_ffi.calloc.free(dret);
    }
  }

  // --- Time/Delta T ---

  /// Compute Delta T (TT - UT) for a given Julian Day.
  ///
  /// Returns Delta T in days. Multiply by 86400 for seconds.
  double deltat(double jd) {
    return _bind.swe_deltat(jd);
  }

  /// Compute Delta T with explicit ephemeris flag.
  ///
  /// [flags] selects the ephemeris (e.g. [seFlgSwiEph], [seFlgMosEph]).
  /// Returns Delta T in days.
  double deltatEx(double jd, int flags) {
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      return _bind.swe_deltat_ex(jd, flags, serr);
    } finally {
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Compute the equation of time for a given Julian Day.
  ///
  /// Returns the equation of time in days (difference between
  /// apparent and mean solar time). Multiply by 1440 for minutes.
  double timeEqu(double jd) {
    final te = pkg_ffi.calloc<ffi.Double>(1);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_time_equ(jd, te, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return te[0];
    } finally {
      pkg_ffi.calloc.free(te);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Compute sidereal time at a given Julian Day (UT).
  ///
  /// Returns sidereal time in hours (0–24).
  double sidTime(double jdUt) {
    return _bind.swe_sidtime(jdUt);
  }

  /// Compute sidereal time with explicit obliquity and nutation.
  ///
  /// [jdUt] is the Julian Day (UT). [eps] is the obliquity of the ecliptic,
  /// [nut] is the nutation in longitude, both in degrees.
  /// Returns sidereal time in hours (0–24).
  double sidTime0(double jdUt, double eps, double nut) {
    return _bind.swe_sidtime0(jdUt, eps, nut);
  }

  /// Convert local mean time to local apparent time.
  ///
  /// [jdLmt] is the Julian Day in LMT, [geolon] is the geographic longitude.
  /// Returns the Julian Day in LAT.
  double lmtToLat(double jdLmt, double geolon) {
    final jdLat = pkg_ffi.calloc<ffi.Double>(1);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_lmt_to_lat(jdLmt, geolon, jdLat, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return jdLat[0];
    } finally {
      pkg_ffi.calloc.free(jdLat);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Convert local apparent time to local mean time.
  ///
  /// [jdLat] is the Julian Day in LAT, [geolon] is the geographic longitude.
  /// Returns the Julian Day in LMT.
  double latToLmt(double jdLat, double geolon) {
    final jdLmt = pkg_ffi.calloc<ffi.Double>(1);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_lat_to_lmt(jdLat, geolon, jdLmt, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return jdLmt[0];
    } finally {
      pkg_ffi.calloc.free(jdLmt);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Set a user-defined Delta T value.
  ///
  /// [dt] is the Delta T in days. Pass [seDeltatAutomatic] (-1E-10) to
  /// revert to automatic calculation.
  void setDeltaTUserdef(double dt) {
    _bind.swe_set_delta_t_userdef(dt);
  }

  /// Get the current tidal acceleration value used for Delta T.
  double getTidAcc() {
    return _bind.swe_get_tid_acc();
  }

  /// Set the tidal acceleration value used for Delta T.
  void setTidAcc(double tidAcc) {
    _bind.swe_set_tid_acc(tidAcc);
  }

  // --- More utilities ---

  /// Normalize a radian value to 0–2*pi range.
  double radNorm(double x) {
    return _bind.swe_radnorm(x);
  }

  /// Compute the midpoint of two degree values (handles wrap-around).
  double degMidp(double x1, double x0) {
    return _bind.swe_deg_midp(x1, x0);
  }

  /// Compute the midpoint of two radian values (handles wrap-around).
  double radMidp(double x1, double x0) {
    return _bind.swe_rad_midp(x1, x0);
  }

  /// Split a degree value into degrees, minutes, seconds, and sign.
  ///
  /// [degrees] is the input value. [roundFlag] controls rounding
  /// (e.g. [seSplitDegRoundSec], [seSplitDegRoundMin]).
  SplitDegResult splitDeg(double degrees, int roundFlag) {
    final ideg = pkg_ffi.calloc<ffi.Int32>(1);
    final imin = pkg_ffi.calloc<ffi.Int32>(1);
    final isec = pkg_ffi.calloc<ffi.Int32>(1);
    final dsecfr = pkg_ffi.calloc<ffi.Double>(1);
    final isgn = pkg_ffi.calloc<ffi.Int32>(1);
    try {
      _bind.swe_split_deg(degrees, roundFlag, ideg, imin, isec, dsecfr, isgn);
      return SplitDegResult(
        degrees: ideg[0],
        minutes: imin[0],
        seconds: isec[0],
        secondsFraction: dsecfr[0],
        sign: isgn[0],
      );
    } finally {
      pkg_ffi.calloc.free(ideg);
      pkg_ffi.calloc.free(imin);
      pkg_ffi.calloc.free(isec);
      pkg_ffi.calloc.free(dsecfr);
      pkg_ffi.calloc.free(isgn);
    }
  }

  /// Compute the difference p1 - p2 normalized to 0–360 range.
  double difDegn(double p1, double p2) {
    return _bind.swe_difdegn(p1, p2);
  }

  /// Compute the difference p1 - p2 normalized to -180..+180 range.
  double difDeg2n(double p1, double p2) {
    return _bind.swe_difdeg2n(p1, p2);
  }

  // ---- Nodes & Apsides ----

  /// Helper to build a CalcResult from a 6-double pointer.
  CalcResult _calcResultFrom(ffi.Pointer<ffi.Double> p, int retFlag) {
    return CalcResult(
      longitude: p[0],
      latitude: p[1],
      distance: p[2],
      longitudeSpeed: p[3],
      latitudeSpeed: p[4],
      distanceSpeed: p[5],
      returnFlag: retFlag,
    );
  }

  /// Compute planetary nodes and apsides (UT).
  ///
  /// [body] — planet ID, [flags] — calc flags, [method] — seNodBit* constant.
  /// Returns ascending/descending nodes and perihelion/aphelion.
  NodeApsResult nodApsUt(double jdUt, int body, int flags, int method) {
    final xnasc = pkg_ffi.calloc<ffi.Double>(6);
    final xndsc = pkg_ffi.calloc<ffi.Double>(6);
    final xperi = pkg_ffi.calloc<ffi.Double>(6);
    final xaphe = pkg_ffi.calloc<ffi.Double>(6);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_nod_aps_ut(
          jdUt, body, flags, method, xnasc, xndsc, xperi, xaphe, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return NodeApsResult(
        ascending: _calcResultFrom(xnasc, ret),
        descending: _calcResultFrom(xndsc, ret),
        perihelion: _calcResultFrom(xperi, ret),
        aphelion: _calcResultFrom(xaphe, ret),
      );
    } finally {
      pkg_ffi.calloc.free(xnasc);
      pkg_ffi.calloc.free(xndsc);
      pkg_ffi.calloc.free(xperi);
      pkg_ffi.calloc.free(xaphe);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Compute planetary nodes and apsides (ET).
  NodeApsResult nodAps(double jdEt, int body, int flags, int method) {
    final xnasc = pkg_ffi.calloc<ffi.Double>(6);
    final xndsc = pkg_ffi.calloc<ffi.Double>(6);
    final xperi = pkg_ffi.calloc<ffi.Double>(6);
    final xaphe = pkg_ffi.calloc<ffi.Double>(6);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_nod_aps(
          jdEt, body, flags, method, xnasc, xndsc, xperi, xaphe, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return NodeApsResult(
        ascending: _calcResultFrom(xnasc, ret),
        descending: _calcResultFrom(xndsc, ret),
        perihelion: _calcResultFrom(xperi, ret),
        aphelion: _calcResultFrom(xaphe, ret),
      );
    } finally {
      pkg_ffi.calloc.free(xnasc);
      pkg_ffi.calloc.free(xndsc);
      pkg_ffi.calloc.free(xperi);
      pkg_ffi.calloc.free(xaphe);
      pkg_ffi.calloc.free(serr);
    }
  }

  // ---- Orbital elements ----

  /// Get orbital elements of a planet (ET).
  ///
  /// Returns semimajor axis, eccentricity, inclination, and other Keplerian
  /// elements. Uses Moshier or Swiss Ephemeris depending on [flags].
  OrbitalElementsResult getOrbitalElements(double jdEt, int body, int flags) {
    final dret = pkg_ffi.calloc<ffi.Double>(50);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_get_orbital_elements(jdEt, body, flags, dret, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return OrbitalElementsResult(
        semimajorAxis: dret[0],
        eccentricity: dret[1],
        inclination: dret[2],
        ascendingNode: dret[3],
        argPeriapsis: dret[4],
        lonPeriapsis: dret[5],
        meanAnomalyEpoch: dret[6],
        trueAnomalyEpoch: dret[7],
        eccentricAnomalyEpoch: dret[8],
        meanLongitudeEpoch: dret[9],
        siderealPeriodYears: dret[10],
        meanDailyMotion: dret[11],
        tropicalPeriodYears: dret[12],
        synodicPeriodDays: dret[13],
        perihelionPassage: dret[14],
        perihelionDistance: dret[15],
        aphelionDistance: dret[16],
      );
    } finally {
      pkg_ffi.calloc.free(dret);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Get max, min, and true distance of a planet's orbit (ET).
  OrbitDistanceResult orbitMaxMinTrueDistance(
      double jdEt, int body, int flags) {
    final dmax = pkg_ffi.calloc<ffi.Double>(1);
    final dmin = pkg_ffi.calloc<ffi.Double>(1);
    final dtrue = pkg_ffi.calloc<ffi.Double>(1);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_orbit_max_min_true_distance(
          jdEt, body, flags, dmax, dmin, dtrue, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return OrbitDistanceResult(
        maxDist: dmax[0],
        minDist: dmin[0],
        trueDist: dtrue[0],
      );
    } finally {
      pkg_ffi.calloc.free(dmax);
      pkg_ffi.calloc.free(dmin);
      pkg_ffi.calloc.free(dtrue);
      pkg_ffi.calloc.free(serr);
    }
  }

  // ---- Phenomena ----

  /// Compute planetary phenomena (phase angle, elongation, magnitude, etc.) (UT).
  PhenoResult phenoUt(double jdUt, int body, int flags) {
    final attr = pkg_ffi.calloc<ffi.Double>(20);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_pheno_ut(jdUt, body, flags, attr, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return PhenoResult(
        phaseAngle: attr[0],
        phase: attr[1],
        elongation: attr[2],
        apparentDiameter: attr[3],
        apparentMagnitude: attr[4],
      );
    } finally {
      pkg_ffi.calloc.free(attr);
      pkg_ffi.calloc.free(serr);
    }
  }

  /// Compute planetary phenomena (phase angle, elongation, magnitude, etc.) (ET).
  PhenoResult pheno(double jdEt, int body, int flags) {
    final attr = pkg_ffi.calloc<ffi.Double>(20);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    try {
      final ret = _bind.swe_pheno(jdEt, body, flags, attr, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return PhenoResult(
        phaseAngle: attr[0],
        phase: attr[1],
        elongation: attr[2],
        apparentDiameter: attr[3],
        apparentMagnitude: attr[4],
      );
    } finally {
      pkg_ffi.calloc.free(attr);
      pkg_ffi.calloc.free(serr);
    }
  }

  // ---- Heliacal ----

  /// Helper to fill geopos, datm, dobs arrays for heliacal functions.
  void _fillHeliacalInputs(
    ffi.Pointer<ffi.Double> geopos, double geolon, double geolat, double geoalt,
    ffi.Pointer<ffi.Double> datm, AtmoConditions atmo,
    ffi.Pointer<ffi.Double> dobs, ObserverConditions observer,
  ) {
    geopos[0] = geolon;
    geopos[1] = geolat;
    geopos[2] = geoalt;
    datm[0] = atmo.pressure;
    datm[1] = atmo.temperature;
    datm[2] = atmo.humidity;
    datm[3] = atmo.extinction;
    dobs[0] = observer.age;
    dobs[1] = observer.snellenRatio;
    dobs[2] = observer.monoNoBino;
    dobs[3] = observer.telescopeDia;
    dobs[4] = observer.telescopeMag;
    dobs[5] = observer.eyeHeight;
  }

  /// Find the next heliacal rising or setting of a celestial body.
  ///
  /// [jdStart] — start date (JD UT), [objectName] — star name or planet name,
  /// [typeEvent] — seHeliacalRising, seHeliacalSetting, etc.
  HeliacalResult heliacalUt(
    double jdStart, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    required AtmoConditions atmo,
    required ObserverConditions observer,
    required String objectName,
    required int typeEvent,
    int flags = 0,
  }) {
    final geopos = pkg_ffi.calloc<ffi.Double>(3);
    final datm = pkg_ffi.calloc<ffi.Double>(4);
    final dobs = pkg_ffi.calloc<ffi.Double>(6);
    final dret = pkg_ffi.calloc<ffi.Double>(50);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    final objName =
        objectName.toNativeUtf8(allocator: pkg_ffi.calloc).cast<ffi.Char>();
    try {
      _fillHeliacalInputs(geopos, geolon, geolat, geoalt, datm, atmo, dobs, observer);
      final ret = _bind.swe_heliacal_ut(
          jdStart, geopos, datm, dobs, objName, typeEvent, flags, dret, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return HeliacalResult(
        startVisible: dret[0],
        bestVisible: dret[1],
        endVisible: dret[2],
      );
    } finally {
      pkg_ffi.calloc.free(geopos);
      pkg_ffi.calloc.free(datm);
      pkg_ffi.calloc.free(dobs);
      pkg_ffi.calloc.free(dret);
      pkg_ffi.calloc.free(serr);
      pkg_ffi.calloc.free(objName);
    }
  }

  /// Compute heliacal phenomenon details.
  ///
  /// Returns topocentric/geocentric altitudes, azimuths, and visibility arcs.
  HeliacalPhenoResult heliacalPhenoUt(
    double jdUt, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    required AtmoConditions atmo,
    required ObserverConditions observer,
    required String objectName,
    required int typeEvent,
    int flags = 0,
  }) {
    final geopos = pkg_ffi.calloc<ffi.Double>(3);
    final datm = pkg_ffi.calloc<ffi.Double>(4);
    final dobs = pkg_ffi.calloc<ffi.Double>(6);
    final darr = pkg_ffi.calloc<ffi.Double>(50);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    final objName =
        objectName.toNativeUtf8(allocator: pkg_ffi.calloc).cast<ffi.Char>();
    try {
      _fillHeliacalInputs(geopos, geolon, geolat, geoalt, datm, atmo, dobs, observer);
      final ret = _bind.swe_heliacal_pheno_ut(
          jdUt, geopos, datm, dobs, objName, typeEvent, flags, darr, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      final raw = List<double>.generate(50, (i) => darr[i]);
      return HeliacalPhenoResult(
        tcAltitude: darr[0],
        tcApparentAltitude: darr[1],
        gcAltitude: darr[2],
        azimuth: darr[3],
        sunAltitude: darr[4],
        sunAzimuth: darr[5],
        objectActualVisibleArc: darr[7],
        objectMinVisibleArc: darr[8],
        objectOptimalVisibleArc: darr[9],
        raw: raw,
      );
    } finally {
      pkg_ffi.calloc.free(geopos);
      pkg_ffi.calloc.free(datm);
      pkg_ffi.calloc.free(dobs);
      pkg_ffi.calloc.free(darr);
      pkg_ffi.calloc.free(serr);
      pkg_ffi.calloc.free(objName);
    }
  }

  /// Compute the limiting visual magnitude for a celestial object.
  VisLimitResult visLimitMag(
    double jdUt, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    required AtmoConditions atmo,
    required ObserverConditions observer,
    required String objectName,
    int flags = 0,
  }) {
    final geopos = pkg_ffi.calloc<ffi.Double>(3);
    final datm = pkg_ffi.calloc<ffi.Double>(4);
    final dobs = pkg_ffi.calloc<ffi.Double>(6);
    final dret = pkg_ffi.calloc<ffi.Double>(50);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    final objName =
        objectName.toNativeUtf8(allocator: pkg_ffi.calloc).cast<ffi.Char>();
    try {
      _fillHeliacalInputs(geopos, geolon, geolat, geoalt, datm, atmo, dobs, observer);
      final ret = _bind.swe_vis_limit_mag(
          jdUt, geopos, datm, dobs, objName, flags, dret, serr);
      if (ret < 0) {
        throw SweException(serr.cast<pkg_ffi.Utf8>().toDartString(), ret);
      }
      return VisLimitResult(
        limitMagnitude: dret[0],
        objectAltitude: dret[1],
        objectAzimuth: dret[2],
        sunAltitude: dret[3],
        sunAzimuth: dret[4],
        moonAltitude: dret[5],
        moonAzimuth: dret[6],
        objectMagnitude: dret[7],
      );
    } finally {
      pkg_ffi.calloc.free(geopos);
      pkg_ffi.calloc.free(datm);
      pkg_ffi.calloc.free(dobs);
      pkg_ffi.calloc.free(dret);
      pkg_ffi.calloc.free(serr);
      pkg_ffi.calloc.free(objName);
    }
  }

  // ---- Rise/set with true horizon ----

  /// Find rise/set/transit accounting for a non-zero horizon height.
  ///
  /// Same as [riseTrans] but with an additional [horizonHeight] parameter
  /// specifying the height of the local horizon in degrees.
  RiseTransResult riseTransTrueHor(
    double jdUt,
    int body, {
    int epheflag = seFlgMosEph,
    int rsmi = seCalcRise,
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
    required double horizonHeight,
  }) {
    final geopos = pkg_ffi.calloc<ffi.Double>(3);
    final tret = pkg_ffi.calloc<ffi.Double>(10);
    final serr = pkg_ffi.calloc<ffi.Char>(256);
    final starname = pkg_ffi.calloc<ffi.Char>(256);
    try {
      geopos[0] = geolon;
      geopos[1] = geolat;
      geopos[2] = geoalt;

      final ret = _bind.swe_rise_trans_true_hor(
          jdUt, body, starname, epheflag, rsmi, geopos,
          atpress, attemp, horizonHeight, tret, serr);
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
