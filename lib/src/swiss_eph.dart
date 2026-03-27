import 'ffi_types.dart' as ffi;
import 'ffi_types.dart' show Arena, using;

import 'bindings.dart';
import 'constants.dart';
import 'ffi_loader.dart' as loader;
import 'types.dart';
import 'utf8_compat.dart';

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

  /// Load the Swiss Ephemeris library from an explicit [libraryPath].
  ///
  /// [libraryPath] is the path to the compiled shared library (.so/.dylib/.dll).
  /// For isolate safety, each isolate should use a unique .so copy — see
  /// `test/isolate_test.dart`.
  ///
  /// **Native only.** On web, use [SwissEph.load] instead.
  SwissEph(String libraryPath) {
    _lib = loader.loadSwissEph(libraryPath);
    _bind = SweBindings(_lib);
  }

  /// Private constructor from an already-opened library.
  SwissEph._fromLibrary(ffi.DynamicLibrary lib) {
    _lib = lib;
    _bind = SweBindings(lib);
  }

  /// Load the Swiss Ephemeris library asynchronously.
  ///
  /// Works on both native and web:
  /// - **Native:** finds and loads the shared library from build hook output.
  /// - **Web:** loads the WASM module (requires swisseph.js to be loaded).
  ///
  /// This is the recommended constructor for cross-platform code.
  ///
  /// ```dart
  /// final swe = await SwissEph.load();
  /// ```
  static Future<SwissEph> load() async {
    final lib = await loader.loadSwissEphAsync();
    return SwissEph._fromLibrary(lib);
  }

  /// Search for the built library in common locations and load it.
  ///
  /// Looks in: .dart_tool/ (build hook output).
  /// Throws [StateError] if not found.
  ///
  /// **Native only.** On web, use [SwissEph.load] instead.
  factory SwissEph.find() {
    final path = loader.findLibrary();
    return SwissEph(path);
  }

  /// Close the library and free C-side resources.
  void close() {
    _bind.swe_close();
  }

  /// Get the Swiss Ephemeris library version string.
  String version() {
    return using((Arena arena) {
      final buf = arena<ffi.Uint8>(256);
      _bind.swe_version(buf);
      return buf.toDartString();
    });
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
    return using((Arena arena) {
      final pYear = arena<ffi.Int32>();
      final pMonth = arena<ffi.Int32>();
      final pDay = arena<ffi.Int32>();
      final pHour = arena<ffi.Double>();
      _bind.swe_revjul(
          jd, gregorian ? seGregCal : seJulCal, pYear, pMonth, pDay, pHour);
      return DateResult(
        year: pYear.value,
        month: pMonth.value,
        day: pDay.value,
        hour: pHour.value,
      );
    });
  }

  /// Convert a UTC date/time to Julian Day numbers (ET and UT1).
  ///
  /// Returns a [JulianDayPair] with both Ephemeris Time and Universal Time JDs.
  /// Throws [SweException] if the date is invalid.
  JulianDayPair utcToJd(int year, int month, int day, int hour, int min,
      double sec,
      {bool gregorian = true}) {
    return using((Arena arena) {
      final dret = arena<ffi.Double>(2);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_utc_to_jd(
          year, month, day, hour, min, sec,
          gregorian ? seGregCal : seJulCal, dret, serr);
      if (ret < 0) {
        throw SweException(serr.toDartString(), ret);
      }
      return JulianDayPair(et: dret[0], ut1: dret[1]);
    });
  }

  /// Convert a Julian Day (UT1) to UTC date/time.
  DateTimeResult jdToUtc(double jdUt, {bool gregorian = true}) {
    return using((Arena arena) {
      final pYear = arena<ffi.Int32>();
      final pMonth = arena<ffi.Int32>();
      final pDay = arena<ffi.Int32>();
      final pHour = arena<ffi.Int32>();
      final pMin = arena<ffi.Int32>();
      final pSec = arena<ffi.Double>();
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
    });
  }

  /// Convert a Julian Day (ET) to UTC date/time.
  DateTimeResult jdetToUtc(double jdEt, {bool gregorian = true}) {
    return using((Arena arena) {
      final pYear = arena<ffi.Int32>();
      final pMonth = arena<ffi.Int32>();
      final pDay = arena<ffi.Int32>();
      final pHour = arena<ffi.Int32>();
      final pMin = arena<ffi.Int32>();
      final pSec = arena<ffi.Double>();
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
    });
  }

  /// Convert a date/time from one timezone to UTC.
  ///
  /// [timezone] is the offset in hours (e.g. 5.5 for IST, -5 for EST).
  /// The input date/time is in the given timezone; the output is UTC.
  DateTimeResult utcTimeZone(int year, int month, int day, int hour, int min,
      double sec, double timezone) {
    return using((Arena arena) {
      final pYear = arena<ffi.Int32>();
      final pMonth = arena<ffi.Int32>();
      final pDay = arena<ffi.Int32>();
      final pHour = arena<ffi.Int32>();
      final pMin = arena<ffi.Int32>();
      final pSec = arena<ffi.Double>();
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
    });
  }

  /// Validate a date and convert to Julian Day.
  ///
  /// Returns the Julian Day number if the date is valid, or `null` if invalid
  /// (e.g. February 30).
  double? dateConversion(int year, int month, int day, double hour,
      {bool gregorian = true}) {
    return using((Arena arena) {
      final pJd = arena<ffi.Double>();
      final ret = _bind.swe_date_conversion(
          year, month, day, hour,
          gregorian ? 0x67 : 0x6A, // 'g' or 'j'
          pJd);
      if (ret < 0) return null;
      return pJd.value;
    });
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
    using((Arena arena) {
      final pPath = path.toNativeString(arena);
      _bind.swe_set_ephe_path(pPath);
    });
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
    using((Arena arena) {
      final pName = filename.toNativeString(arena);
      _bind.swe_set_jpl_file(pName);
    });
  }

  /// Get the file path of the Swiss Ephemeris library.
  String getLibraryPath() {
    return using((Arena arena) {
      final buf = arena<ffi.Uint8>(256);
      _bind.swe_get_library_path(buf);
      return buf.toDartString();
    });
  }

  /// Get data about a currently loaded ephemeris file.
  ///
  /// [fileNum]: 0 = planet file (e.g. seas_18.se1), 1 = Moon file, 2 = main asteroid file.
  /// Returns [FileDataResult] with the file path (null if no file loaded),
  /// start/end dates, and ephemeris number.
  FileDataResult getCurrentFileData(int fileNum) {
    return using((Arena arena) {
      final pStart = arena<ffi.Double>();
      final pEnd = arena<ffi.Double>();
      final pDenum = arena<ffi.Int32>();
      final ptr = _bind.swe_get_current_file_data(fileNum, pStart, pEnd, pDenum);
      String? path;
      if (ptr.address != 0) {
        final s = ptr.cast<ffi.Uint8>().toDartString();
        if (s.isNotEmpty) path = s;
      }
      return FileDataResult(
        path: path,
        startDate: pStart.value,
        endDate: pEnd.value,
        ephemerisNumber: pDenum.value,
      );
    });
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
    return using((Arena arena) {
      final xx = arena<ffi.Double>(6);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_calc_ut(jdUt, body, flags, xx, serr);
      if (ret < 0) {
        throw SweException(serr.toDartString(), ret);
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
    });
  }

  /// Calculate the position of a celestial body at a given Julian Day (ET).
  ///
  /// Unlike [calcUt], this takes Ephemeris Time (ET/TDB) rather than UT.
  CalcResult calc(double jdEt, int body, int flags) {
    return using((Arena arena) {
      final xx = arena<ffi.Double>(6);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_calc(jdEt, body, flags, xx, serr);
      if (ret < 0) {
        throw SweException(serr.toDartString(), ret);
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
    });
  }

  /// Calculate house cusps for a given time and location.
  HouseResult houses(double jdUt, double geolat, double geolon, int hsys) {
    return using((Arena arena) {
      final pCusps = arena<ffi.Double>(37);
      final pAscmc = arena<ffi.Double>(10);
      final ret = _bind.swe_houses(jdUt, geolat, geolon, hsys, pCusps, pAscmc);
      if (ret < 0) {
        throw SweException('House calculation failed', ret);
      }
      final cuspCount = hsys == 0x47 ? 37 : 13; // 'G' = Gauquelin sectors
      final cusps = List<double>.generate(cuspCount, (i) => pCusps[i]);
      final ascmc = List<double>.generate(10, (i) => pAscmc[i]);
      return HouseResult(cusps: cusps, ascmc: ascmc, returnFlag: ret);
    });
  }

  /// Calculate house cusps with flags (e.g. sidereal).
  ///
  /// Like [houses], but accepts [flags] for sidereal mode etc.
  HouseResult housesEx(double jdUt, int flags, double geolat, double geolon,
      int hsys) {
    return using((Arena arena) {
      final pCusps = arena<ffi.Double>(37);
      final pAscmc = arena<ffi.Double>(10);
      final ret =
          _bind.swe_houses_ex(jdUt, flags, geolat, geolon, hsys, pCusps, pAscmc);
      if (ret < 0) {
        throw SweException('House calculation failed', ret);
      }
      final cuspCount = hsys == 0x47 ? 37 : 13; // 'G' = Gauquelin sectors
      final cusps = List<double>.generate(cuspCount, (i) => pCusps[i]);
      final ascmc = List<double>.generate(10, (i) => pAscmc[i]);
      return HouseResult(cusps: cusps, ascmc: ascmc, returnFlag: ret);
    });
  }

  /// Calculate house cusps with speeds.
  ///
  /// Returns [HouseResultEx] which includes cusp and ascmc speeds.
  HouseResultEx housesEx2(double jdUt, int flags, double geolat, double geolon,
      int hsys) {
    return using((Arena arena) {
      final pCusps = arena<ffi.Double>(37);
      final pAscmc = arena<ffi.Double>(10);
      final pCuspSpeed = arena<ffi.Double>(37);
      final pAscmcSpeed = arena<ffi.Double>(10);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_houses_ex2(
          jdUt, flags, geolat, geolon, hsys,
          pCusps, pAscmc, pCuspSpeed, pAscmcSpeed, serr);
      if (ret < 0) {
        throw SweException(serr.toDartString(), ret);
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
    });
  }

  /// Calculate house cusps from ARMC.
  ///
  /// [armc] is the right ascension of the MC, [geolat] is geographic latitude,
  /// [eps] is the obliquity of the ecliptic.
  HouseResult housesArmc(double armc, double geolat, double eps, int hsys) {
    return using((Arena arena) {
      final pCusps = arena<ffi.Double>(37);
      final pAscmc = arena<ffi.Double>(10);
      final ret =
          _bind.swe_houses_armc(armc, geolat, eps, hsys, pCusps, pAscmc);
      if (ret < 0) {
        throw SweException('House calculation failed', ret);
      }
      final cuspCount = hsys == 0x47 ? 37 : 13; // 'G' = Gauquelin sectors
      final cusps = List<double>.generate(cuspCount, (i) => pCusps[i]);
      final ascmc = List<double>.generate(10, (i) => pAscmc[i]);
      return HouseResult(cusps: cusps, ascmc: ascmc, returnFlag: ret);
    });
  }

  /// Calculate house cusps from ARMC with speeds.
  ///
  /// Like [housesArmc], but returns [HouseResultEx] with cusp and ascmc speeds.
  HouseResultEx housesArmcEx2(
      double armc, double geolat, double eps, int hsys) {
    return using((Arena arena) {
      final pCusps = arena<ffi.Double>(37);
      final pAscmc = arena<ffi.Double>(10);
      final pCuspSpeed = arena<ffi.Double>(37);
      final pAscmcSpeed = arena<ffi.Double>(10);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_houses_armc_ex2(
          armc, geolat, eps, hsys,
          pCusps, pAscmc, pCuspSpeed, pAscmcSpeed, serr);
      if (ret < 0) {
        throw SweException(serr.toDartString(), ret);
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
    });
  }

  /// Determine the house position of a body.
  ///
  /// Returns a double between 1.0 and 12.999... indicating the house position.
  /// [armc] is the right ascension of the MC, [geolat] is geographic latitude,
  /// [eps] is the obliquity of the ecliptic, [bodyLon] and [bodyLat] are the
  /// ecliptic coordinates of the body.
  double housePos(double armc, double geolat, double eps, int hsys,
      double bodyLon, double bodyLat) {
    return using((Arena arena) {
      final xpin = arena<ffi.Double>(2);
      final serr = arena<ffi.Uint8>(256);
      xpin[0] = bodyLon;
      xpin[1] = bodyLat;
      final result =
          _bind.swe_house_pos(armc, geolat, eps, hsys, xpin, serr);
      if (result == 0.0) {
        final msg = serr.toDartString();
        throw SweException(msg.isEmpty ? 'swe_house_pos failed' : msg, 0);
      }
      return result;
    });
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
    return using((Arena arena) {
      final geopos = arena<ffi.Double>(3);
      final dgsect = arena<ffi.Double>(1);
      final serr = arena<ffi.Uint8>(256);
      final starnameBuf = arena<ffi.Uint8>(256);
      if (starName != null) {
        final starBytes = starName.toNativeString(arena, 256);
        for (int i = 0; i < 256; i++) {
          starnameBuf[i] = starBytes[i];
          if (starBytes[i] == 0) break;
        }
      }
      geopos[0] = geolon;
      geopos[1] = geolat;
      geopos[2] = geoalt;
      final ret = _bind.swe_gauquelin_sector(
          jdUt, body, starnameBuf, flags, method, geopos, atpress, attemp,
          dgsect, serr);
      if (ret < 0) {
        throw SweException(serr.toDartString(), ret);
      }
      return dgsect[0];
    });
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
    return using((Arena arena) {
      final pAya = arena<ffi.Double>();
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_get_ayanamsa_ex_ut(jdUt, flags, pAya, serr);
      if (ret < 0) {
        throw SweException(serr.toDartString(), ret);
      }
      return AyanamsaResult(ayanamsa: pAya.value, returnFlag: ret);
    });
  }

  /// Get the ayanamsa value with extended flags (ET).
  AyanamsaResult getAyanamsaEx(double jdEt, int flags) {
    return using((Arena arena) {
      final pAya = arena<ffi.Double>();
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_get_ayanamsa_ex(jdEt, flags, pAya, serr);
      if (ret < 0) {
        throw SweException(serr.toDartString(), ret);
      }
      return AyanamsaResult(ayanamsa: pAya.value, returnFlag: ret);
    });
  }

  /// Get the name of an ayanamsa mode.
  String getAyanamsaName(int sidMode) {
    final ptr = _bind.swe_get_ayanamsa_name(sidMode);
    return ptr.cast<ffi.Uint8>().toDartString();
  }

  // --- Names ---

  /// Get the name of a celestial body.
  String getPlanetName(int body) {
    return using((Arena arena) {
      final buf = arena<ffi.Uint8>(256);
      _bind.swe_get_planet_name(body, buf);
      return buf.toDartString();
    });
  }

  /// Get the name of a house system.
  String houseName(int hsys) {
    final ptr = _bind.swe_house_name(hsys);
    return ptr.cast<ffi.Uint8>().toDartString();
  }

  // --- Fixed stars ---

  /// Look up a fixed star position at a given Julian Day (UT).
  ///
  /// [star] is the star name or search string (e.g. "Sirius", "Aldebaran").
  /// The returned [FixstarResult.starName] contains the resolved full name.
  FixstarResult fixstar2Ut(String star, double jdUt, int flags) {
    return using((Arena arena) {
      final starBuf = arena<ffi.Uint8>(512);
      final xx = arena<ffi.Double>(6);
      final serr = arena<ffi.Uint8>(256);
      final starBytes = star.toNativeString(arena, 512);
      for (int i = 0; i < 512; i++) {
        starBuf[i] = starBytes[i];
        if (starBytes[i] == 0) break;
      }
      final ret = _bind.swe_fixstar2_ut(starBuf, jdUt, flags, xx, serr);
      if (ret < 0) {
        throw SweException(serr.toDartString(), ret);
      }
      final resolvedName = starBuf.toDartString();
      return FixstarResult(
        starName: resolvedName,
        longitude: xx[0], latitude: xx[1], distance: xx[2],
        longitudeSpeed: xx[3], latitudeSpeed: xx[4], distanceSpeed: xx[5],
        returnFlag: ret,
      );
    });
  }

  /// Look up a fixed star position at a given Julian Day (ET).
  ///
  /// [star] is the star name or search string (e.g. "Sirius", "Aldebaran").
  /// The returned [FixstarResult.starName] contains the resolved full name.
  FixstarResult fixstar2(String star, double jdEt, int flags) {
    return using((Arena arena) {
      final starBuf = arena<ffi.Uint8>(512);
      final xx = arena<ffi.Double>(6);
      final serr = arena<ffi.Uint8>(256);
      final starBytes = star.toNativeString(arena, 512);
      for (int i = 0; i < 512; i++) {
        starBuf[i] = starBytes[i];
        if (starBytes[i] == 0) break;
      }
      final ret = _bind.swe_fixstar2(starBuf, jdEt, flags, xx, serr);
      if (ret < 0) {
        throw SweException(serr.toDartString(), ret);
      }
      final resolvedName = starBuf.toDartString();
      return FixstarResult(
        starName: resolvedName,
        longitude: xx[0], latitude: xx[1], distance: xx[2],
        longitudeSpeed: xx[3], latitudeSpeed: xx[4], distanceSpeed: xx[5],
        returnFlag: ret,
      );
    });
  }

  /// Get the visual magnitude of a fixed star.
  ///
  /// [star] is the star name or search string.
  double fixstar2Mag(String star) {
    return using((Arena arena) {
      final starBuf = arena<ffi.Uint8>(512);
      final mag = arena<ffi.Double>(1);
      final serr = arena<ffi.Uint8>(256);
      final starBytes = star.toNativeString(arena, 512);
      for (int i = 0; i < 512; i++) {
        starBuf[i] = starBytes[i];
        if (starBytes[i] == 0) break;
      }
      final ret = _bind.swe_fixstar2_mag(starBuf, mag, serr);
      if (ret < 0) {
        throw SweException(serr.toDartString(), ret);
      }
      return mag[0];
    });
  }

  // --- Crossing functions ---

  /// Find the next time the Sun crosses a given ecliptic longitude (UT).
  ///
  /// Throws [SweException] if the crossing cannot be found.
  double solCrossUt(double longitude, double jdUt, int flags) {
    return using((Arena arena) {
      final serr = arena<ffi.Uint8>(256);
      final result = _bind.swe_solcross_ut(longitude, jdUt, flags, serr);
      if (result < jdUt) {
        throw SweException(serr.toDartString(), -1);
      }
      return result;
    });
  }

  /// Find the next time the Sun crosses a given ecliptic longitude (ET).
  double solCross(double longitude, double jdEt, int flags) {
    return using((Arena arena) {
      final serr = arena<ffi.Uint8>(256);
      final result = _bind.swe_solcross(longitude, jdEt, flags, serr);
      if (result < jdEt) {
        throw SweException(serr.toDartString(), -1);
      }
      return result;
    });
  }

  /// Find the next time the Moon crosses a given ecliptic longitude (UT).
  double moonCrossUt(double longitude, double jdUt, int flags) {
    return using((Arena arena) {
      final serr = arena<ffi.Uint8>(256);
      final result = _bind.swe_mooncross_ut(longitude, jdUt, flags, serr);
      if (result < jdUt) {
        throw SweException(serr.toDartString(), -1);
      }
      return result;
    });
  }

  /// Find the next time the Moon crosses a given ecliptic longitude (ET).
  double moonCross(double longitude, double jdEt, int flags) {
    return using((Arena arena) {
      final serr = arena<ffi.Uint8>(256);
      final result = _bind.swe_mooncross(longitude, jdEt, flags, serr);
      if (result < jdEt) {
        throw SweException(serr.toDartString(), -1);
      }
      return result;
    });
  }

  /// Find the next time the Moon crosses its node (UT).
  MoonNodeCrossResult moonCrossNodeUt(double jdUt, int flags) {
    return using((Arena arena) {
      final xlon = arena<ffi.Double>(1);
      final xlat = arena<ffi.Double>(1);
      final serr = arena<ffi.Uint8>(256);
      final result = _bind.swe_mooncross_node_ut(jdUt, flags, xlon, xlat, serr);
      if (result < jdUt) {
        throw SweException(serr.toDartString(), -1);
      }
      return MoonNodeCrossResult(
        jdUt: result,
        longitude: xlon[0],
        latitude: xlat[0],
      );
    });
  }

  /// Find the next time the Moon crosses its node (ET).
  MoonNodeCrossResult moonCrossNode(double jdEt, int flags) {
    return using((Arena arena) {
      final xlon = arena<ffi.Double>(1);
      final xlat = arena<ffi.Double>(1);
      final serr = arena<ffi.Uint8>(256);
      final result = _bind.swe_mooncross_node(jdEt, flags, xlon, xlat, serr);
      if (result < jdEt) {
        throw SweException(serr.toDartString(), -1);
      }
      return MoonNodeCrossResult(
        jdUt: result,
        longitude: xlon[0],
        latitude: xlat[0],
      );
    });
  }

  /// Find the next heliocentric crossing of a longitude (UT).
  double helioCrossUt(int body, double longitude, double jdUt, int flags, int dir) {
    return using((Arena arena) {
      final jdCross = arena<ffi.Double>(1);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_helio_cross_ut(
          body, longitude, jdUt, flags, dir, jdCross, serr);
      if (ret < 0) {
        throw SweException(serr.toDartString(), ret);
      }
      return jdCross[0];
    });
  }

  /// Find the next heliocentric crossing of a longitude (ET).
  double helioCross(int body, double longitude, double jdEt, int flags, int dir) {
    return using((Arena arena) {
      final jdCross = arena<ffi.Double>(1);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_helio_cross(
          body, longitude, jdEt, flags, dir, jdCross, serr);
      if (ret < 0) {
        throw SweException(serr.toDartString(), ret);
      }
      return jdCross[0];
    });
  }

  // --- Utilities ---

  /// Normalize a degree value to 0..360.
  double degnorm(double x) {
    return _bind.swe_degnorm(x);
  }

  /// Normalize a radian value to 0..2*PI.
  double radNorm(double x) => _bind.swe_radnorm(x);

  /// Calculate the midpoint of two degree values.
  double degMidp(double x1, double x0) => _bind.swe_deg_midp(x1, x0);

  /// Calculate the midpoint of two radian values.
  double radMidp(double x1, double x0) => _bind.swe_rad_midp(x1, x0);

  /// Split a degree value into degrees, minutes, seconds.
  SplitDegResult splitDeg(double degrees, int roundFlag) {
    return using((Arena arena) {
      final ideg = arena<ffi.Int32>(1);
      final imin = arena<ffi.Int32>(1);
      final isec = arena<ffi.Int32>(1);
      final dsecfr = arena<ffi.Double>(1);
      final isgn = arena<ffi.Int32>(1);
      _bind.swe_split_deg(degrees, roundFlag, ideg, imin, isec, dsecfr, isgn);
      return SplitDegResult(
        degrees: ideg[0], minutes: imin[0], seconds: isec[0],
        secondsFraction: dsecfr[0], sign: isgn[0],
      );
    });
  }

  /// Calculate the difference between two degree values (0..360).
  double difDegn(double p1, double p2) => _bind.swe_difdegn(p1, p2);

  /// Calculate the difference between two degree values (-180..180).
  double difDeg2n(double p1, double p2) => _bind.swe_difdeg2n(p1, p2);

  // --- Eclipses ---

  /// Find the next solar eclipse visible from a given location (UT).
  SolarEclipseLocalResult solEclipseWhenLoc(double jdStart, int flags,
      {required double geolon, required double geolat, double geoalt = 0,
       bool backward = false}) {
    return using((Arena arena) {
      final geopos = arena<ffi.Double>(3);
      final tret = arena<ffi.Double>(10);
      final attr = arena<ffi.Double>(20);
      final serr = arena<ffi.Uint8>(256);
      geopos[0] = geolon; geopos[1] = geolat; geopos[2] = geoalt;
      final ret = _bind.swe_sol_eclipse_when_loc(
          jdStart, flags, geopos, tret, attr, backward ? 1 : 0, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
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
    });
  }

  /// Find the next solar eclipse globally (UT).
  SolarEclipseGlobalResult solEclipseWhenGlob(double jdStart, int flags,
      {int eclType = 0, bool backward = false}) {
    return using((Arena arena) {
      final tret = arena<ffi.Double>(10);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_sol_eclipse_when_glob(
          jdStart, flags, eclType, tret, backward ? 1 : 0, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return SolarEclipseGlobalResult(
        maxEclipse: tret[0], localNoon: tret[1],
        begin: tret[2], end: tret[3],
        totalityBegin: tret[4], totalityEnd: tret[5],
        centerLineBegin: tret[6], centerLineEnd: tret[7],
        annularTotalBegin: tret[8], annularTotalEnd: tret[9],
        returnFlag: ret,
      );
    });
  }

  /// Get attributes of a solar eclipse at a given location and time.
  SolarEclipseAttrResult solEclipseHow(double jdUt, int flags,
      {required double geolon, required double geolat, double geoalt = 0}) {
    return using((Arena arena) {
      final geopos = arena<ffi.Double>(3);
      final attr = arena<ffi.Double>(20);
      final serr = arena<ffi.Uint8>(256);
      geopos[0] = geolon; geopos[1] = geolat; geopos[2] = geoalt;
      final ret = _bind.swe_sol_eclipse_how(jdUt, flags, geopos, attr, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return SolarEclipseAttrResult(
        magnitude: attr[0], diameterRatio: attr[1], obscuration: attr[2],
        coreShadowKm: attr[3], sunAzimuth: attr[4], sunTrueAltitude: attr[5],
        sunApparentAltitude: attr[6], moonSunAngle: attr[7],
        magnitudeNasa: attr[8], sarosSeries: attr[9], sarosMember: attr[10],
        returnFlag: ret,
      );
    });
  }

  /// Find where on earth a solar eclipse is central at a given time.
  EclipseWhereResult solEclipseWhere(double jdUt, int flags) {
    return using((Arena arena) {
      final geopos = arena<ffi.Double>(2);
      final attr = arena<ffi.Double>(20);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_sol_eclipse_where(jdUt, flags, geopos, attr, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return EclipseWhereResult(
        geolon: geopos[0], geolat: geopos[1],
        magnitude: attr[0], diameterRatio: attr[1], obscuration: attr[2],
        coreShadowKm: attr[3], sunAzimuth: attr[4], sunTrueAltitude: attr[5],
        sunApparentAltitude: attr[6], moonSunAngle: attr[7],
        returnFlag: ret,
      );
    });
  }

  /// Find the next lunar eclipse globally (UT).
  LunarEclipseGlobalResult lunEclipseWhen(double jdStart, int flags,
      {int eclType = 0, bool backward = false}) {
    return using((Arena arena) {
      final tret = arena<ffi.Double>(10);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_lun_eclipse_when(
          jdStart, flags, eclType, tret, backward ? 1 : 0, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return LunarEclipseGlobalResult(
        maxEclipse: tret[0],
        partialBegin: tret[2], partialEnd: tret[3],
        totalityBegin: tret[4], totalityEnd: tret[5],
        penumbralBegin: tret[6], penumbralEnd: tret[7],
        returnFlag: ret,
      );
    });
  }

  /// Find the next lunar eclipse visible from a given location (UT).
  LunarEclipseLocalResult lunEclipseWhenLoc(double jdStart, int flags,
      {required double geolon, required double geolat, double geoalt = 0,
       bool backward = false}) {
    return using((Arena arena) {
      final geopos = arena<ffi.Double>(3);
      final tret = arena<ffi.Double>(10);
      final attr = arena<ffi.Double>(20);
      final serr = arena<ffi.Uint8>(256);
      geopos[0] = geolon; geopos[1] = geolat; geopos[2] = geoalt;
      final ret = _bind.swe_lun_eclipse_when_loc(
          jdStart, flags, geopos, tret, attr, backward ? 1 : 0, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
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
    });
  }

  /// Get attributes of a lunar eclipse at a given location and time.
  LunarEclipseAttrResult lunEclipseHow(double jdUt, int flags,
      {required double geolon, required double geolat, double geoalt = 0}) {
    return using((Arena arena) {
      final geopos = arena<ffi.Double>(3);
      final attr = arena<ffi.Double>(20);
      final serr = arena<ffi.Uint8>(256);
      geopos[0] = geolon; geopos[1] = geolat; geopos[2] = geoalt;
      final ret = _bind.swe_lun_eclipse_how(jdUt, flags, geopos, attr, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return LunarEclipseAttrResult(
        umbralMagnitude: attr[0], penumbralMagnitude: attr[1],
        moonAzimuth: attr[4], moonTrueAltitude: attr[5],
        moonApparentAltitude: attr[6], moonOppositionAngle: attr[7],
        sarosSeries: attr[9], sarosMember: attr[10],
        returnFlag: ret,
      );
    });
  }

  // --- Occultations ---

  /// Find the next lunar occultation visible from a given location (UT).
  SolarEclipseLocalResult lunOccultWhenLoc(double jdStart, int body, int flags,
      {String? starname, required double geolon, required double geolat,
       double geoalt = 0, bool backward = false}) {
    return using((Arena arena) {
      final geopos = arena<ffi.Double>(3);
      final tret = arena<ffi.Double>(10);
      final attr = arena<ffi.Double>(20);
      final serr = arena<ffi.Uint8>(256);
      final starPtr = starname?.toNativeString(arena) ?? ffi.nullptr.cast<ffi.Uint8>();
      geopos[0] = geolon; geopos[1] = geolat; geopos[2] = geoalt;
      final ret = _bind.swe_lun_occult_when_loc(
          jdStart, body, starPtr, flags, geopos, tret, attr,
          backward ? 1 : 0, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
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
    });
  }

  /// Find the next lunar occultation globally (UT).
  SolarEclipseGlobalResult lunOccultWhenGlob(double jdStart, int body, int flags,
      {String? starname, int eclType = 0, bool backward = false}) {
    return using((Arena arena) {
      final tret = arena<ffi.Double>(10);
      final serr = arena<ffi.Uint8>(256);
      final starPtr = starname?.toNativeString(arena) ?? ffi.nullptr.cast<ffi.Uint8>();
      final ret = _bind.swe_lun_occult_when_glob(
          jdStart, body, starPtr, flags, eclType, tret, backward ? 1 : 0, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return SolarEclipseGlobalResult(
        maxEclipse: tret[0], localNoon: tret[1],
        begin: tret[2], end: tret[3],
        totalityBegin: tret[4], totalityEnd: tret[5],
        centerLineBegin: tret[6], centerLineEnd: tret[7],
        annularTotalBegin: tret[8], annularTotalEnd: tret[9],
        returnFlag: ret,
      );
    });
  }

  /// Find where on earth a lunar occultation is central at a given time.
  EclipseWhereResult lunOccultWhere(double jdUt, int body, int flags,
      {String? starname}) {
    return using((Arena arena) {
      final geopos = arena<ffi.Double>(2);
      final attr = arena<ffi.Double>(20);
      final serr = arena<ffi.Uint8>(256);
      final starPtr = starname?.toNativeString(arena) ?? ffi.nullptr.cast<ffi.Uint8>();
      final ret = _bind.swe_lun_occult_where(
          jdUt, body, starPtr, flags, geopos, attr, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return EclipseWhereResult(
        geolon: geopos[0], geolat: geopos[1],
        magnitude: attr[0], diameterRatio: attr[1], obscuration: attr[2],
        coreShadowKm: attr[3], sunAzimuth: attr[4], sunTrueAltitude: attr[5],
        sunApparentAltitude: attr[6], moonSunAngle: attr[7],
        returnFlag: ret,
      );
    });
  }

  // --- Rise/set ---

  /// Calculate rise or set time of a body.
  RiseTransResult riseTrans(
    double jdUt, int body, {
    int epheflag = seFlgMosEph,
    int rsmi = seCalcRise,
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
  }) {
    return using((Arena arena) {
      final geopos = arena<ffi.Double>(3);
      final tret = arena<ffi.Double>(10);
      final serr = arena<ffi.Uint8>(256);
      final starname = arena<ffi.Uint8>(256);
      geopos[0] = geolon; geopos[1] = geolat; geopos[2] = geoalt;
      final ret = _bind.swe_rise_trans(
          jdUt, body, starname, epheflag, rsmi, geopos, atpress, attemp,
          tret, serr);
      if (ret < 0) {
        throw SweException(serr.toDartString(), ret);
      }
      return RiseTransResult(transitTime: tret[0], returnFlag: ret);
    });
  }

  /// Calculate rise or set time with true horizon.
  RiseTransResult riseTransTrueHor(double jdUt, int body, {
    int epheflag = seFlgMosEph,
    int rsmi = seCalcRise,
    required double geolon, required double geolat,
    double geoalt = 0, double atpress = 1013.25, double attemp = 15.0,
    required double horizonHeight,
  }) {
    return using((Arena arena) {
      final geopos = arena<ffi.Double>(3);
      final tret = arena<ffi.Double>(10);
      final serr = arena<ffi.Uint8>(256);
      final starname = arena<ffi.Uint8>(256);
      geopos[0] = geolon; geopos[1] = geolat; geopos[2] = geoalt;
      final ret = _bind.swe_rise_trans_true_hor(
          jdUt, body, starname, epheflag, rsmi, geopos,
          atpress, attemp, horizonHeight, tret, serr);
      if (ret < 0) {
        throw SweException(serr.toDartString(), ret);
      }
      return RiseTransResult(transitTime: tret[0], returnFlag: ret);
    });
  }

  // --- Horizon/Coordinates ---

  /// Convert ecliptic coordinates to horizontal (azimuth/altitude).
  AzAltResult azAlt(double jdUt, int calcFlag,
      {required double geolon, required double geolat, double geoalt = 0,
       double atpress = 1013.25, double attemp = 15.0,
       required double bodyLon, required double bodyLat, double bodyDist = 1.0}) {
    return using((Arena arena) {
      final geopos = arena<ffi.Double>(3);
      final xin = arena<ffi.Double>(3);
      final xaz = arena<ffi.Double>(3);
      geopos[0] = geolon; geopos[1] = geolat; geopos[2] = geoalt;
      xin[0] = bodyLon; xin[1] = bodyLat; xin[2] = bodyDist;
      _bind.swe_azalt(jdUt, calcFlag, geopos, atpress, attemp, xin, xaz);
      return AzAltResult(
        azimuth: xaz[0], trueAltitude: xaz[1], apparentAltitude: xaz[2],
      );
    });
  }

  /// Convert horizontal coordinates back to ecliptic.
  AzAltRevResult azAltRev(double jdUt, int calcFlag,
      {required double geolon, required double geolat, double geoalt = 0,
       required double azimuth, required double altitude}) {
    return using((Arena arena) {
      final geopos = arena<ffi.Double>(3);
      final xin = arena<ffi.Double>(2);
      final xout = arena<ffi.Double>(2);
      geopos[0] = geolon; geopos[1] = geolat; geopos[2] = geoalt;
      xin[0] = azimuth; xin[1] = altitude;
      _bind.swe_azalt_rev(jdUt, calcFlag, geopos, xin, xout);
      return AzAltRevResult(lon: xout[0], lat: xout[1]);
    });
  }

  /// Coordinate transformation (ecliptic ↔ equatorial).
  CoTransResult cotrans(double lon, double lat, double dist, double eps) {
    return using((Arena arena) {
      final xpo = arena<ffi.Double>(3);
      final xpn = arena<ffi.Double>(3);
      xpo[0] = lon; xpo[1] = lat; xpo[2] = dist;
      _bind.swe_cotrans(xpo, xpn, eps);
      return CoTransResult(lon: xpn[0], lat: xpn[1], dist: xpn[2]);
    });
  }

  /// Calculate atmospheric refraction.
  double refrac(double altitude, double atpress, double attemp, int calcFlag) {
    return _bind.swe_refrac(altitude, atpress, attemp, calcFlag);
  }

  /// Calculate extended atmospheric refraction.
  RefracResult refracExtended(double altitude, double geoalt,
      double atpress, double attemp, double lapseRate, int calcFlag) {
    return using((Arena arena) {
      final dret = arena<ffi.Double>(4);
      _bind.swe_refrac_extended(
          altitude, geoalt, atpress, attemp, lapseRate, calcFlag, dret);
      return RefracResult(
        trueAltitude: dret[0], apparentAltitude: dret[1],
        refraction: dret[2], horizonDip: dret[3],
      );
    });
  }

  // --- Time/Delta T ---

  /// Get Delta T for a given Julian Day.
  double deltat(double jd) => _bind.swe_deltat(jd);

  /// Get Delta T with extended flags.
  double deltatEx(double jd, int flags) {
    return using((Arena arena) {
      final serr = arena<ffi.Uint8>(256);
      return _bind.swe_deltat_ex(jd, flags, serr);
    });
  }

  /// Get the equation of time for a given Julian Day.
  double timeEqu(double jd) {
    return using((Arena arena) {
      final te = arena<ffi.Double>(1);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_time_equ(jd, te, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return te[0];
    });
  }

  /// Get sidereal time for a given Julian Day (UT).
  double sidTime(double jdUt) => _bind.swe_sidtime(jdUt);

  /// Get sidereal time with explicit obliquity and nutation.
  double sidTime0(double jdUt, double eps, double nut) =>
      _bind.swe_sidtime0(jdUt, eps, nut);

  /// Convert Local Mean Time to Local Apparent Time.
  double lmtToLat(double jdLmt, double geolon) {
    return using((Arena arena) {
      final jdLat = arena<ffi.Double>(1);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_lmt_to_lat(jdLmt, geolon, jdLat, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return jdLat[0];
    });
  }

  /// Convert Local Apparent Time to Local Mean Time.
  double latToLmt(double jdLat, double geolon) {
    return using((Arena arena) {
      final jdLmt = arena<ffi.Double>(1);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_lat_to_lmt(jdLat, geolon, jdLmt, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return jdLmt[0];
    });
  }

  /// Set a user-defined Delta T value.
  void setDeltaTUserdef(double dt) => _bind.swe_set_delta_t_userdef(dt);

  /// Get the tidal acceleration value.
  double getTidAcc() => _bind.swe_get_tid_acc();

  /// Set the tidal acceleration value.
  void setTidAcc(double tidAcc) => _bind.swe_set_tid_acc(tidAcc);

  // --- Nodes & Apsides ---

  CalcResult _calcResultFrom(ffi.Pointer<ffi.Double> p, int retFlag) {
    return CalcResult(
      longitude: p[0], latitude: p[1], distance: p[2],
      longitudeSpeed: p[3], latitudeSpeed: p[4], distanceSpeed: p[5],
      returnFlag: retFlag,
    );
  }

  /// Calculate nodes and apsides of a body (UT).
  NodeApsResult nodApsUt(double jdUt, int body, int flags, int method) {
    return using((Arena arena) {
      final xnasc = arena<ffi.Double>(6);
      final xndsc = arena<ffi.Double>(6);
      final xperi = arena<ffi.Double>(6);
      final xaphe = arena<ffi.Double>(6);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_nod_aps_ut(
          jdUt, body, flags, method, xnasc, xndsc, xperi, xaphe, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return NodeApsResult(
        ascending: _calcResultFrom(xnasc, ret),
        descending: _calcResultFrom(xndsc, ret),
        perihelion: _calcResultFrom(xperi, ret),
        aphelion: _calcResultFrom(xaphe, ret),
      );
    });
  }

  /// Calculate nodes and apsides of a body (ET).
  NodeApsResult nodAps(double jdEt, int body, int flags, int method) {
    return using((Arena arena) {
      final xnasc = arena<ffi.Double>(6);
      final xndsc = arena<ffi.Double>(6);
      final xperi = arena<ffi.Double>(6);
      final xaphe = arena<ffi.Double>(6);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_nod_aps(
          jdEt, body, flags, method, xnasc, xndsc, xperi, xaphe, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return NodeApsResult(
        ascending: _calcResultFrom(xnasc, ret),
        descending: _calcResultFrom(xndsc, ret),
        perihelion: _calcResultFrom(xperi, ret),
        aphelion: _calcResultFrom(xaphe, ret),
      );
    });
  }

  // --- Orbital elements ---

  /// Get orbital elements of a body.
  OrbitalElementsResult getOrbitalElements(double jdEt, int body, int flags) {
    return using((Arena arena) {
      final dret = arena<ffi.Double>(50);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_get_orbital_elements(jdEt, body, flags, dret, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return OrbitalElementsResult(
        semimajorAxis: dret[0], eccentricity: dret[1], inclination: dret[2],
        ascendingNode: dret[3], argPeriapsis: dret[4], lonPeriapsis: dret[5],
        meanAnomalyEpoch: dret[6], trueAnomalyEpoch: dret[7],
        eccentricAnomalyEpoch: dret[8], meanLongitudeEpoch: dret[9],
        siderealPeriodYears: dret[10], meanDailyMotion: dret[11],
        tropicalPeriodYears: dret[12], synodicPeriodDays: dret[13],
        perihelionPassage: dret[14], perihelionDistance: dret[15],
        aphelionDistance: dret[16],
      );
    });
  }

  /// Get maximum, minimum, and true distance of a body from Earth.
  OrbitDistanceResult orbitMaxMinTrueDistance(double jdEt, int body, int flags) {
    return using((Arena arena) {
      final dmax = arena<ffi.Double>(1);
      final dmin = arena<ffi.Double>(1);
      final dtrue = arena<ffi.Double>(1);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_orbit_max_min_true_distance(
          jdEt, body, flags, dmax, dmin, dtrue, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return OrbitDistanceResult(maxDist: dmax[0], minDist: dmin[0], trueDist: dtrue[0]);
    });
  }

  // --- Phenomena ---

  /// Calculate planetary phenomena (phase angle, phase, elongation, etc.) (UT).
  PhenoResult phenoUt(double jdUt, int body, int flags) {
    return using((Arena arena) {
      final attr = arena<ffi.Double>(20);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_pheno_ut(jdUt, body, flags, attr, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return PhenoResult(
        phaseAngle: attr[0], phase: attr[1], elongation: attr[2],
        apparentDiameter: attr[3], apparentMagnitude: attr[4],
      );
    });
  }

  /// Calculate planetary phenomena (phase angle, phase, elongation, etc.) (ET).
  PhenoResult pheno(double jdEt, int body, int flags) {
    return using((Arena arena) {
      final attr = arena<ffi.Double>(20);
      final serr = arena<ffi.Uint8>(256);
      final ret = _bind.swe_pheno(jdEt, body, flags, attr, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return PhenoResult(
        phaseAngle: attr[0], phase: attr[1], elongation: attr[2],
        apparentDiameter: attr[3], apparentMagnitude: attr[4],
      );
    });
  }

  // --- Heliacal ---

  void _fillHeliacalInputs(
    ffi.Pointer<ffi.Double> geopos, double geolon, double geolat, double geoalt,
    ffi.Pointer<ffi.Double> datm, AtmoConditions atmo,
    ffi.Pointer<ffi.Double> dobs, ObserverConditions observer,
  ) {
    geopos[0] = geolon; geopos[1] = geolat; geopos[2] = geoalt;
    datm[0] = atmo.pressure; datm[1] = atmo.temperature;
    datm[2] = atmo.humidity; datm[3] = atmo.extinction;
    dobs[0] = observer.age; dobs[1] = observer.snellenRatio;
    dobs[2] = observer.monoNoBino; dobs[3] = observer.telescopeDia;
    dobs[4] = observer.telescopeMag; dobs[5] = observer.eyeHeight;
  }

  /// Calculate heliacal rising/setting of a body.
  HeliacalResult heliacalUt(double jdStart, {
    required double geolon, required double geolat, double geoalt = 0,
    required AtmoConditions atmo, required ObserverConditions observer,
    required String objectName, required int typeEvent, int flags = 0,
  }) {
    return using((Arena arena) {
      final geopos = arena<ffi.Double>(3);
      final datm = arena<ffi.Double>(4);
      final dobs = arena<ffi.Double>(6);
      final dret = arena<ffi.Double>(50);
      final serr = arena<ffi.Uint8>(256);
      final objName = objectName.toNativeString(arena);
      _fillHeliacalInputs(geopos, geolon, geolat, geoalt, datm, atmo, dobs, observer);
      final ret = _bind.swe_heliacal_ut(
          jdStart, geopos, datm, dobs, objName, typeEvent, flags, dret, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return HeliacalResult(
        startVisible: dret[0], bestVisible: dret[1], endVisible: dret[2],
      );
    });
  }

  /// Calculate heliacal phenomena of a body.
  HeliacalPhenoResult heliacalPhenoUt(double jdUt, {
    required double geolon, required double geolat, double geoalt = 0,
    required AtmoConditions atmo, required ObserverConditions observer,
    required String objectName, required int typeEvent, int flags = 0,
  }) {
    return using((Arena arena) {
      final geopos = arena<ffi.Double>(3);
      final datm = arena<ffi.Double>(4);
      final dobs = arena<ffi.Double>(6);
      final darr = arena<ffi.Double>(50);
      final serr = arena<ffi.Uint8>(256);
      final objName = objectName.toNativeString(arena);
      _fillHeliacalInputs(geopos, geolon, geolat, geoalt, datm, atmo, dobs, observer);
      final ret = _bind.swe_heliacal_pheno_ut(
          jdUt, geopos, datm, dobs, objName, typeEvent, flags, darr, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      final raw = List<double>.generate(50, (i) => darr[i]);
      return HeliacalPhenoResult(
        tcAltitude: darr[0], tcApparentAltitude: darr[1], gcAltitude: darr[2],
        azimuth: darr[3], sunAltitude: darr[4], sunAzimuth: darr[5],
        objectActualVisibleArc: darr[7], objectMinVisibleArc: darr[8],
        objectOptimalVisibleArc: darr[9], raw: raw,
      );
    });
  }

  /// Calculate visibility limit magnitude.
  VisLimitResult visLimitMag(double jdUt, {
    required double geolon, required double geolat, double geoalt = 0,
    required AtmoConditions atmo, required ObserverConditions observer,
    required String objectName, int flags = 0,
  }) {
    return using((Arena arena) {
      final geopos = arena<ffi.Double>(3);
      final datm = arena<ffi.Double>(4);
      final dobs = arena<ffi.Double>(6);
      final dret = arena<ffi.Double>(50);
      final serr = arena<ffi.Uint8>(256);
      final objName = objectName.toNativeString(arena);
      _fillHeliacalInputs(geopos, geolon, geolat, geoalt, datm, atmo, dobs, observer);
      final ret = _bind.swe_vis_limit_mag(
          jdUt, geopos, datm, dobs, objName, flags, dret, serr);
      if (ret < 0) throw SweException(serr.toDartString(), ret);
      return VisLimitResult(
        limitMagnitude: dret[0], objectAltitude: dret[1], objectAzimuth: dret[2],
        sunAltitude: dret[3], sunAzimuth: dret[4],
        moonAltitude: dret[5], moonAzimuth: dret[6], objectMagnitude: dret[7],
      );
    });
  }
}
