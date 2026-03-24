/// Return type for swe_calc_ut / swe_calc.
/// The xx[6] array: longitude, latitude, distance, speed in lon, speed in lat, speed in dist.
class CalcResult {
  final double longitude;
  final double latitude;
  final double distance;
  final double longitudeSpeed;
  final double latitudeSpeed;
  final double distanceSpeed;

  /// The return flag from swe_calc_ut (indicates which flags were actually computed).
  final int returnFlag;

  const CalcResult({
    required this.longitude,
    required this.latitude,
    required this.distance,
    required this.longitudeSpeed,
    required this.latitudeSpeed,
    required this.distanceSpeed,
    required this.returnFlag,
  });

  @override
  String toString() =>
      'CalcResult(lon: $longitude, lat: $latitude, dist: $distance, '
      'lonSpd: $longitudeSpeed, latSpd: $latitudeSpeed, distSpd: $distanceSpeed)';
}

/// Return type for swe_houses / swe_houses_ex.
class HouseResult {
  /// House cusps. Index 0 is unused (C convention); cusps[1] through cusps[12]
  /// are the 12 house cusps. For Gauquelin sectors, cusps[1]–cusps[36].
  final List<double> cusps;

  /// Ascendant, MC, and related points.
  /// [0] Ascendant, [1] MC, [2] ARMC, [3] Vertex,
  /// [4] equatorial ascendant, [5] co-ascendant (Koch),
  /// [6] co-ascendant (Munkasey), [7] polar ascendant.
  final List<double> ascmc;

  /// Return flag.
  final int returnFlag;

  const HouseResult({
    required this.cusps,
    required this.ascmc,
    required this.returnFlag,
  });

  double get ascendant => ascmc[0];
  double get mc => ascmc[1];
  double get armc => ascmc[2];
  double get vertex => ascmc[3];
}

/// Return type for swe_get_ayanamsa_ex_ut.
class AyanamsaResult {
  final double ayanamsa;
  final int returnFlag;

  const AyanamsaResult({required this.ayanamsa, required this.returnFlag});
}

/// Return type for swe_revjul.
class DateResult {
  final int year;
  final int month;
  final int day;
  final double hour;

  const DateResult({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
  });

  @override
  String toString() => 'DateResult($year-$month-$day ${hour}h)';
}

/// Return type for swe_rise_trans.
///
/// A [returnFlag] of -2 indicates a circumpolar body that never rises or sets
/// at the given location; [transitTime] will be 0.0 in that case.
class RiseTransResult {
  final double transitTime;
  final int returnFlag;

  const RiseTransResult({
    required this.transitTime,
    required this.returnFlag,
  });
}

/// Return type for utcToJd — Julian Day pair.
class JulianDayPair {
  final double et;   // dret[0] — Ephemeris Time
  final double ut1;  // dret[1] — Universal Time

  const JulianDayPair({required this.et, required this.ut1});

  @override
  String toString() => 'JulianDayPair(et: $et, ut1: $ut1)';
}

/// Return type for jdToUtc, jdetToUtc, utcTimeZone.
/// Separate hour/min/sec fields for leap-second-aware UTC handling.
class DateTimeResult {
  final int year;
  final int month;
  final int day;
  final int hour;
  final int min;
  final double sec;

  const DateTimeResult({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.min,
    required this.sec,
  });

  @override
  String toString() =>
      'DateTimeResult($year-$month-$day ${hour}:${min}:${sec})';
}

/// Return type for getCurrentFileData.
class FileDataResult {
  final String? path;         // null if no file loaded
  final double startDate;     // tfstart
  final double endDate;       // tfend
  final int ephemerisNumber;  // denum

  const FileDataResult({
    required this.path,
    required this.startDate,
    required this.endDate,
    required this.ephemerisNumber,
  });

  @override
  String toString() =>
      'FileDataResult(path: $path, start: $startDate, end: $endDate, denum: $ephemerisNumber)';
}

/// Return type for housesEx2 / housesArmcEx2 — cusps with speeds.
class HouseResultEx {
  /// House cusps. Index 0 is unused (C convention); cusps[1] through cusps[12]
  /// are the 12 house cusps.
  final List<double> cusps;

  /// Ascendant, MC, and related points.
  /// [0] Ascendant, [1] MC, [2] ARMC, [3] Vertex,
  /// [4] equatorial ascendant, [5] co-ascendant (Koch),
  /// [6] co-ascendant (Munkasey), [7] polar ascendant.
  final List<double> ascmc;

  /// Speed of each cusp (same indexing as cusps).
  final List<double> cuspSpeeds;

  /// Speed of each ascmc point (same indexing as ascmc).
  final List<double> ascmcSpeeds;

  /// Return flag.
  final int returnFlag;

  const HouseResultEx({
    required this.cusps,
    required this.ascmc,
    required this.cuspSpeeds,
    required this.ascmcSpeeds,
    required this.returnFlag,
  });

  double get ascendant => ascmc[0];
  double get mc => ascmc[1];
  double get armc => ascmc[2];
  double get vertex => ascmc[3];
  double get ascendantSpeed => ascmcSpeeds[0];
  double get mcSpeed => ascmcSpeeds[1];
  double get armcSpeed => ascmcSpeeds[2];
  double get vertexSpeed => ascmcSpeeds[3];
}

/// Return type for fixstar2Ut / fixstar2 — star position with resolved name.
class FixstarResult {
  final String starName;
  final double longitude;
  final double latitude;
  final double distance;
  final double longitudeSpeed;
  final double latitudeSpeed;
  final double distanceSpeed;

  /// The return flag from swe_fixstar2 (indicates which flags were actually computed).
  final int returnFlag;

  const FixstarResult({
    required this.starName,
    required this.longitude,
    required this.latitude,
    required this.distance,
    required this.longitudeSpeed,
    required this.latitudeSpeed,
    required this.distanceSpeed,
    required this.returnFlag,
  });

  @override
  String toString() =>
      'FixstarResult(star: $starName, lon: $longitude, lat: $latitude, dist: $distance)';
}

/// Return type for moonCrossNodeUt / moonCrossNode.
class MoonNodeCrossResult {
  final double jdUt;
  final double longitude;
  final double latitude;

  const MoonNodeCrossResult({
    required this.jdUt,
    required this.longitude,
    required this.latitude,
  });

  @override
  String toString() =>
      'MoonNodeCrossResult(jd: $jdUt, lon: $longitude, lat: $latitude)';
}

/// Return type for solEclipseWhenLoc / lunOccultWhenLoc.
class SolarEclipseLocalResult {
  // Timing (from tret[])
  final double maxEclipse;          // tret[0]
  final double firstContact;        // tret[1]
  final double secondContact;       // tret[2]
  final double thirdContact;        // tret[3]
  final double fourthContact;       // tret[4]
  final double sunrise;             // tret[5]
  final double sunset;              // tret[6]
  // Attributes (from attr[])
  final double magnitude;           // attr[0]
  final double diameterRatio;       // attr[1]
  final double obscuration;         // attr[2]
  final double coreShadowKm;        // attr[3]
  final double sunAzimuth;          // attr[4]
  final double sunTrueAltitude;     // attr[5]
  final double sunApparentAltitude; // attr[6]
  final double moonSunAngle;        // attr[7]
  final double magnitudeNasa;       // attr[8]
  final double sarosSeries;         // attr[9]
  final double sarosMember;         // attr[10]
  final int returnFlag;

  const SolarEclipseLocalResult({
    required this.maxEclipse,
    required this.firstContact,
    required this.secondContact,
    required this.thirdContact,
    required this.fourthContact,
    required this.sunrise,
    required this.sunset,
    required this.magnitude,
    required this.diameterRatio,
    required this.obscuration,
    required this.coreShadowKm,
    required this.sunAzimuth,
    required this.sunTrueAltitude,
    required this.sunApparentAltitude,
    required this.moonSunAngle,
    required this.magnitudeNasa,
    required this.sarosSeries,
    required this.sarosMember,
    required this.returnFlag,
  });
}

/// Return type for solEclipseWhenGlob.
class SolarEclipseGlobalResult {
  final double maxEclipse;          // tret[0]
  final double localNoon;           // tret[1]
  final double begin;               // tret[2]
  final double end;                 // tret[3]
  final double totalityBegin;       // tret[4]
  final double totalityEnd;         // tret[5]
  final double centerLineBegin;     // tret[6]
  final double centerLineEnd;       // tret[7]
  final double annularTotalBegin;   // tret[8]
  final double annularTotalEnd;     // tret[9]
  final int returnFlag;

  const SolarEclipseGlobalResult({
    required this.maxEclipse,
    required this.localNoon,
    required this.begin,
    required this.end,
    required this.totalityBegin,
    required this.totalityEnd,
    required this.centerLineBegin,
    required this.centerLineEnd,
    required this.annularTotalBegin,
    required this.annularTotalEnd,
    required this.returnFlag,
  });
}

/// Return type for solEclipseHow.
class SolarEclipseAttrResult {
  final double magnitude;           // attr[0]
  final double diameterRatio;       // attr[1]
  final double obscuration;         // attr[2]
  final double coreShadowKm;        // attr[3]
  final double sunAzimuth;          // attr[4]
  final double sunTrueAltitude;     // attr[5]
  final double sunApparentAltitude; // attr[6]
  final double moonSunAngle;        // attr[7]
  final double magnitudeNasa;       // attr[8]
  final double sarosSeries;         // attr[9]
  final double sarosMember;         // attr[10]
  final int returnFlag;

  const SolarEclipseAttrResult({
    required this.magnitude,
    required this.diameterRatio,
    required this.obscuration,
    required this.coreShadowKm,
    required this.sunAzimuth,
    required this.sunTrueAltitude,
    required this.sunApparentAltitude,
    required this.moonSunAngle,
    required this.magnitudeNasa,
    required this.sarosSeries,
    required this.sarosMember,
    required this.returnFlag,
  });
}

/// Return type for solEclipseWhere / lunOccultWhere.
class EclipseWhereResult {
  final double geolon;              // geopos[0]
  final double geolat;              // geopos[1]
  final double magnitude;           // attr[0]
  final double diameterRatio;       // attr[1]
  final double obscuration;         // attr[2]
  final double coreShadowKm;        // attr[3]
  final double sunAzimuth;          // attr[4]
  final double sunTrueAltitude;     // attr[5]
  final double sunApparentAltitude; // attr[6]
  final double moonSunAngle;        // attr[7]
  final int returnFlag;

  const EclipseWhereResult({
    required this.geolon,
    required this.geolat,
    required this.magnitude,
    required this.diameterRatio,
    required this.obscuration,
    required this.coreShadowKm,
    required this.sunAzimuth,
    required this.sunTrueAltitude,
    required this.sunApparentAltitude,
    required this.moonSunAngle,
    required this.returnFlag,
  });
}

/// Return type for lunEclipseWhen.
class LunarEclipseGlobalResult {
  final double maxEclipse;          // tret[0]
  // Note: tret[1] is not used for lunar eclipses
  final double partialBegin;        // tret[2]
  final double partialEnd;          // tret[3]
  final double totalityBegin;       // tret[4]
  final double totalityEnd;         // tret[5]
  final double penumbralBegin;      // tret[6]
  final double penumbralEnd;        // tret[7]
  final int returnFlag;

  const LunarEclipseGlobalResult({
    required this.maxEclipse,
    required this.partialBegin,
    required this.partialEnd,
    required this.totalityBegin,
    required this.totalityEnd,
    required this.penumbralBegin,
    required this.penumbralEnd,
    required this.returnFlag,
  });
}

/// Return type for lunEclipseWhenLoc.
class LunarEclipseLocalResult {
  // Timing
  final double maxEclipse;          // tret[0]
  final double partialBegin;        // tret[2]
  final double partialEnd;          // tret[3]
  final double totalityBegin;       // tret[4]
  final double totalityEnd;         // tret[5]
  final double penumbralBegin;      // tret[6]
  final double penumbralEnd;        // tret[7]
  final double moonrise;            // tret[8]
  final double moonset;             // tret[9]
  // Attributes
  final double umbralMagnitude;     // attr[0]
  final double penumbralMagnitude;  // attr[1]
  final double moonAzimuth;         // attr[4]
  final double moonTrueAltitude;    // attr[5]
  final double moonApparentAltitude;// attr[6]
  final double moonOppositionAngle; // attr[7]
  final double sarosSeries;         // attr[9]
  final double sarosMember;         // attr[10]
  final int returnFlag;

  const LunarEclipseLocalResult({
    required this.maxEclipse,
    required this.partialBegin,
    required this.partialEnd,
    required this.totalityBegin,
    required this.totalityEnd,
    required this.penumbralBegin,
    required this.penumbralEnd,
    required this.moonrise,
    required this.moonset,
    required this.umbralMagnitude,
    required this.penumbralMagnitude,
    required this.moonAzimuth,
    required this.moonTrueAltitude,
    required this.moonApparentAltitude,
    required this.moonOppositionAngle,
    required this.sarosSeries,
    required this.sarosMember,
    required this.returnFlag,
  });
}

/// Return type for lunEclipseHow.
class LunarEclipseAttrResult {
  final double umbralMagnitude;     // attr[0]
  final double penumbralMagnitude;  // attr[1]
  final double moonAzimuth;         // attr[4]
  final double moonTrueAltitude;    // attr[5]
  final double moonApparentAltitude;// attr[6]
  final double moonOppositionAngle; // attr[7]
  final double sarosSeries;         // attr[9]
  final double sarosMember;         // attr[10]
  final int returnFlag;

  const LunarEclipseAttrResult({
    required this.umbralMagnitude,
    required this.penumbralMagnitude,
    required this.moonAzimuth,
    required this.moonTrueAltitude,
    required this.moonApparentAltitude,
    required this.moonOppositionAngle,
    required this.sarosSeries,
    required this.sarosMember,
    required this.returnFlag,
  });
}

/// Return type for azAlt.
class AzAltResult {
  final double azimuth;
  final double trueAltitude;
  final double apparentAltitude;
  const AzAltResult({required this.azimuth, required this.trueAltitude,
    required this.apparentAltitude});
}

/// Return type for azAltRev.
class AzAltRevResult {
  final double lon;
  final double lat;
  const AzAltRevResult({required this.lon, required this.lat});
}

/// Return type for cotrans.
class CoTransResult {
  final double lon;
  final double lat;
  final double dist;
  const CoTransResult({required this.lon, required this.lat, required this.dist});
}

/// Return type for refracExtended.
class RefracResult {
  final double trueAltitude;       // dret[0]
  final double apparentAltitude;   // dret[1]
  final double refraction;         // dret[2]
  final double horizonDip;         // dret[3]
  const RefracResult({required this.trueAltitude, required this.apparentAltitude,
    required this.refraction, required this.horizonDip});
}

/// Return type for splitDeg.
class SplitDegResult {
  final int degrees;
  final int minutes;
  final int seconds;
  final double secondsFraction;
  /// 1=positive, -1=negative. With SE_SPLIT_DEG_ZODIACAL: zodiac sign index (0–11).
  final int sign;
  const SplitDegResult({required this.degrees, required this.minutes,
    required this.seconds, required this.secondsFraction, required this.sign});
}

/// Atmospheric conditions for heliacal functions.
/// Wraps the C datm[4] array with named fields.
class AtmoConditions {
  /// Atmospheric pressure in mbar
  final double pressure;
  /// Atmospheric temperature in degrees Celsius
  final double temperature;
  /// Relative humidity in percent
  final double humidity;
  /// Atmospheric extinction coefficient
  final double extinction;

  const AtmoConditions({
    required this.pressure,
    required this.temperature,
    required this.humidity,
    required this.extinction,
  });
}

/// Observer conditions for heliacal functions.
/// Wraps the C dobs[6] array with named fields.
class ObserverConditions {
  /// Observer age in years
  final double age;
  /// Snellen ratio (default 1.0)
  final double snellenRatio;
  /// 0 = use binocular, 1 = monocular
  final double monoNoBino;
  /// Telescope aperture diameter in mm
  final double telescopeDia;
  /// Telescope magnification
  final double telescopeMag;
  /// Observer eye height above ground in meters
  final double eyeHeight;

  const ObserverConditions({
    this.age = 36,
    this.snellenRatio = 1.0,
    this.monoNoBino = 1,
    this.telescopeDia = 0,
    this.telescopeMag = 0,
    this.eyeHeight = 0,
  });
}

/// Return type for nodApsUt / nodAps.
class NodeApsResult {
  /// Ascending node (6 doubles: lon, lat, dist, speeds)
  final CalcResult ascending;
  /// Descending node (6 doubles: lon, lat, dist, speeds)
  final CalcResult descending;
  /// Perihelion (6 doubles: lon, lat, dist, speeds)
  final CalcResult perihelion;
  /// Aphelion (6 doubles: lon, lat, dist, speeds)
  final CalcResult aphelion;

  const NodeApsResult({
    required this.ascending,
    required this.descending,
    required this.perihelion,
    required this.aphelion,
  });
}

/// Return type for getOrbitalElements.
class OrbitalElementsResult {
  final double semimajorAxis;
  final double eccentricity;
  final double inclination;
  final double ascendingNode;
  final double argPeriapsis;
  final double lonPeriapsis;
  final double meanAnomalyEpoch;
  final double trueAnomalyEpoch;
  final double eccentricAnomalyEpoch;
  final double meanLongitudeEpoch;
  final double siderealPeriodYears;
  final double meanDailyMotion;
  final double tropicalPeriodYears;
  final double synodicPeriodDays;
  final double perihelionPassage;
  final double perihelionDistance;
  final double aphelionDistance;

  const OrbitalElementsResult({
    required this.semimajorAxis,
    required this.eccentricity,
    required this.inclination,
    required this.ascendingNode,
    required this.argPeriapsis,
    required this.lonPeriapsis,
    required this.meanAnomalyEpoch,
    required this.trueAnomalyEpoch,
    required this.eccentricAnomalyEpoch,
    required this.meanLongitudeEpoch,
    required this.siderealPeriodYears,
    required this.meanDailyMotion,
    required this.tropicalPeriodYears,
    required this.synodicPeriodDays,
    required this.perihelionPassage,
    required this.perihelionDistance,
    required this.aphelionDistance,
  });

  @override
  String toString() =>
      'OrbitalElementsResult(a: $semimajorAxis, e: $eccentricity, i: $inclination)';
}

/// Return type for orbitMaxMinTrueDistance.
class OrbitDistanceResult {
  final double maxDist;
  final double minDist;
  final double trueDist;

  const OrbitDistanceResult({
    required this.maxDist,
    required this.minDist,
    required this.trueDist,
  });

  @override
  String toString() =>
      'OrbitDistanceResult(max: $maxDist, min: $minDist, true: $trueDist)';
}

/// Return type for phenoUt / pheno.
class PhenoResult {
  /// Phase angle (degrees)
  final double phaseAngle;
  /// Phase (illuminated fraction of disc)
  final double phase;
  /// Elongation (degrees)
  final double elongation;
  /// Apparent diameter (degrees)
  final double apparentDiameter;
  /// Apparent magnitude
  final double apparentMagnitude;

  const PhenoResult({
    required this.phaseAngle,
    required this.phase,
    required this.elongation,
    required this.apparentDiameter,
    required this.apparentMagnitude,
  });

  @override
  String toString() =>
      'PhenoResult(phaseAngle: $phaseAngle, phase: $phase, elong: $elongation, '
      'diam: $apparentDiameter, mag: $apparentMagnitude)';
}

/// Return type for heliacalUt.
class HeliacalResult {
  /// Start of visibility (JD UT)
  final double startVisible;
  /// Best visibility (JD UT)
  final double bestVisible;
  /// End of visibility (JD UT)
  final double endVisible;

  const HeliacalResult({
    required this.startVisible,
    required this.bestVisible,
    required this.endVisible,
  });

  @override
  String toString() =>
      'HeliacalResult(start: $startVisible, best: $bestVisible, end: $endVisible)';
}

/// Return type for heliacalPhenoUt.
class HeliacalPhenoResult {
  final double tcAltitude;
  final double tcApparentAltitude;
  final double gcAltitude;
  final double azimuth;
  final double sunAltitude;
  final double sunAzimuth;
  final double objectActualVisibleArc;
  final double objectMinVisibleArc;
  final double objectOptimalVisibleArc;
  /// Full darr[0..49] array for advanced use
  final List<double> raw;

  const HeliacalPhenoResult({
    required this.tcAltitude,
    required this.tcApparentAltitude,
    required this.gcAltitude,
    required this.azimuth,
    required this.sunAltitude,
    required this.sunAzimuth,
    required this.objectActualVisibleArc,
    required this.objectMinVisibleArc,
    required this.objectOptimalVisibleArc,
    required this.raw,
  });
}

/// Return type for visLimitMag.
class VisLimitResult {
  final double limitMagnitude;
  final double objectAltitude;
  final double objectAzimuth;
  final double sunAltitude;
  final double sunAzimuth;
  final double moonAltitude;
  final double moonAzimuth;
  final double objectMagnitude;

  const VisLimitResult({
    required this.limitMagnitude,
    required this.objectAltitude,
    required this.objectAzimuth,
    required this.sunAltitude,
    required this.sunAzimuth,
    required this.moonAltitude,
    required this.moonAzimuth,
    required this.objectMagnitude,
  });

  @override
  String toString() =>
      'VisLimitResult(limitMag: $limitMagnitude, objAlt: $objectAltitude, '
      'objMag: $objectMagnitude)';
}

/// Exception thrown when a Swiss Ephemeris function reports an error.
class SweException implements Exception {
  final String message;
  final int returnFlag;

  const SweException(this.message, this.returnFlag);

  @override
  String toString() => 'SweException($returnFlag): $message';
}
