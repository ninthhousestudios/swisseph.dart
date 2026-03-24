import 'package:test/test.dart';
import 'package:swisseph/swisseph.dart';

void main() {
  late SwissEph swe;

  setUp(() {
    swe = SwissEph.find();
  });

  tearDown(() {
    swe.close();
  });

  group('azAlt', () {
    test('compute azimuth/altitude of Sun at J2000 noon from Greenwich', () {
      // J2000.0 = 2000-01-01 12:00 UT — Sun near winter solstice
      final jd = 2451545.0;
      // Get Sun position first
      final sun = swe.calcUt(jd, seSun, seflgMoseph);

      final result = swe.azAlt(jd, seEcl2hor,
          geolon: 0.0, geolat: 51.48,
          bodyLon: sun.longitude, bodyLat: sun.latitude,
          bodyDist: sun.distance);

      // swe_azalt azimuth is measured from south, westward:
      //   0° = south, 90° = west, 180° = north, 270° = east
      // At noon in London the Sun should be roughly due south,
      // so azimuth should be near 0° (or equivalently near 360°).
      expect(result.azimuth > 350 || result.azimuth < 10, isTrue);
      // Winter in London: Sun altitude should be low but positive at noon
      expect(result.trueAltitude, greaterThan(5));
      expect(result.trueAltitude, lessThan(25));
      // Apparent altitude should be >= true altitude (refraction lifts it)
      expect(result.apparentAltitude,
          greaterThanOrEqualTo(result.trueAltitude));
    });
  });

  group('azAltRev', () {
    test('roundtrip: azAlt then azAltRev recovers approximate equatorial coords', () {
      final jd = 2451545.0;
      // Get Sun equatorial position
      final sun = swe.calcUt(jd, seSun, seflgMoseph | seflgEquatorial);

      // Convert equatorial to horizontal
      final hor = swe.azAlt(jd, seEqu2hor,
          geolon: 0.0, geolat: 51.48,
          bodyLon: sun.longitude, bodyLat: sun.latitude,
          bodyDist: sun.distance);

      // Convert back to equatorial
      final rev = swe.azAltRev(jd, seHor2equ,
          geolon: 0.0, geolat: 51.48,
          azimuth: hor.azimuth, altitude: hor.trueAltitude);

      // Should recover original RA/dec approximately
      expect(rev.lon, closeTo(sun.longitude, 0.5));
      expect(rev.lat, closeTo(sun.latitude, 0.5));
    });
  });

  group('cotrans', () {
    test('ecliptic (0°, 0°) to equatorial at vernal equinox', () {
      // The vernal equinox (0° Aries) is at RA=0, Dec=0 by definition
      // Negative eps = ecliptic -> equatorial
      final result = swe.cotrans(0.0, 0.0, 1.0, -23.44);
      expect(result.lon, closeTo(0.0, 0.01));
      expect(result.lat, closeTo(0.0, 0.01));
      expect(result.dist, closeTo(1.0, 0.01));
    });

    test('ecliptic (90°, 0°) converts to equatorial with expected dec', () {
      // 90° ecliptic longitude, 0° latitude -> RA~90°, Dec~23.44°
      // swe_cotrans with positive eps rotates ecliptic -> equatorial
      // but the dec comes out negative due to the rotation direction.
      // Use negative eps for ecliptic->equatorial (per SE docs).
      final result = swe.cotrans(90.0, 0.0, 1.0, -23.44);
      expect(result.lon, closeTo(90.0, 0.5));
      expect(result.lat, closeTo(23.44, 0.5));
    });
  });

  group('refrac', () {
    test('true-to-apparent refraction at 0° altitude adds positive correction', () {
      final apparent = swe.refrac(0.0, 1013.25, 15.0, seTrueToApp);
      // At the horizon, refraction adds about 34 arcminutes (~0.57°)
      expect(apparent, greaterThan(0.0));
      expect(apparent, closeTo(0.57, 0.1));
    });

    test('app-to-true at 1° apparent subtracts refraction', () {
      final trueAlt = swe.refrac(1.0, 1013.25, 15.0, seAppToTrue);
      // True altitude should be less than apparent altitude
      expect(trueAlt, lessThan(1.0));
      expect(trueAlt, greaterThan(0.0));
    });
  });

  group('splitDeg', () {
    test('split 123.456° with round-to-seconds', () {
      final result = swe.splitDeg(123.456, seSplitDegRoundSec);
      expect(result.degrees, equals(123));
      expect(result.minutes, equals(27));
      // 0.456° = 27.36' = 27' 21.6" -> rounded to 22"
      expect(result.seconds, closeTo(22, 1));
      expect(result.sign, equals(1));
    });

    test('negative degrees produce negative sign', () {
      final result = swe.splitDeg(-45.5, seSplitDegRoundSec);
      expect(result.degrees, equals(45));
      expect(result.minutes, equals(30));
      expect(result.sign, equals(-1));
    });
  });
}
