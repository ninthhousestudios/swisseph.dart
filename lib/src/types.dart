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
class RiseTransResult {
  final double transitTime;
  final int returnFlag;

  const RiseTransResult({
    required this.transitTime,
    required this.returnFlag,
  });
}

/// Exception thrown when a Swiss Ephemeris function reports an error.
class SweException implements Exception {
  final String message;
  final int returnFlag;

  const SweException(this.message, this.returnFlag);

  @override
  String toString() => 'SweException($returnFlag): $message';
}
