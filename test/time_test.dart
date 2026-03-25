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

  group('deltat', () {
    test('delta T at J2000 is approximately 63-64 seconds', () {
      final dt = swe.deltat(2451545.0);
      // Delta T in days; convert to seconds
      final dtSeconds = dt * 86400;
      expect(dtSeconds, greaterThan(63));
      expect(dtSeconds, lessThan(65));
    });

    test('deltatEx matches deltat for Moshier', () {
      final dt1 = swe.deltat(2451545.0);
      final dt2 = swe.deltatEx(2451545.0, seFlgMosEph);
      expect(dt2, closeTo(dt1, 1e-10));
    });
  });

  group('sidTime', () {
    test('sidereal time at J2000.0 is approximately 18.7 hours', () {
      final gst = swe.sidTime(2451545.0);
      // Known GST at J2000.0 (2000-01-01 12:00 UT) ≈ 18.697 hours
      expect(gst, closeTo(18.697, 0.01));
    });
  });

  group('timeEqu', () {
    test('equation of time at J2000 is a small value', () {
      final eot = swe.timeEqu(2451545.0);
      // Equation of time in days; should be small (a few minutes)
      final eotMinutes = eot * 1440;
      expect(eotMinutes.abs(), lessThan(20));
    });
  });

  group('lmtToLat / latToLmt', () {
    test('roundtrip LMT -> LAT -> LMT', () {
      final jdLmt = 2451545.0;
      final geolon = 10.0; // 10° East

      final jdLat = swe.lmtToLat(jdLmt, geolon);
      final jdBack = swe.latToLmt(jdLat, geolon);

      expect(jdBack, closeTo(jdLmt, 1e-8));
    });

    test('LAT differs from LMT by equation of time', () {
      final jdLmt = 2451545.0;
      final jdLat = swe.lmtToLat(jdLmt, 0.0); // Greenwich

      // Should differ by the equation of time
      final diff = (jdLat - jdLmt).abs();
      // Equation of time is at most ~16 minutes ≈ 0.011 days
      expect(diff, lessThan(0.012));
    });
  });

  group('degMidp', () {
    test('midpoint of 350° and 10° wraps around to 0°', () {
      final mid = swe.degMidp(350.0, 10.0);
      expect(mid, closeTo(0.0, 0.01));
    });

    test('midpoint of 90° and 270° is 0° or 180°', () {
      final mid = swe.degMidp(90.0, 270.0);
      // The "near" midpoint is 0° or 180° depending on implementation
      final isNear0 = (mid < 0.01) || (mid > 359.99);
      final isNear180 = (mid - 180.0).abs() < 0.01;
      expect(isNear0 || isNear180, isTrue);
    });
  });

  group('difDeg2n', () {
    test('difference of 10° and 350° is 20°', () {
      final diff = swe.difDeg2n(10.0, 350.0);
      expect(diff, closeTo(20.0, 0.01));
    });

    test('difference of 350° and 10° is -20°', () {
      final diff = swe.difDeg2n(350.0, 10.0);
      expect(diff, closeTo(-20.0, 0.01));
    });
  });

  group('difDegn', () {
    test('positive normalized difference', () {
      final diff = swe.difDegn(10.0, 350.0);
      expect(diff, closeTo(20.0, 0.01));
    });
  });

  group('radNorm', () {
    test('normalizes negative radian', () {
      final result = swe.radNorm(-1.0);
      expect(result, greaterThanOrEqualTo(0));
      expect(result, lessThan(6.2832));
    });
  });

  group('setDeltaTUserdef / getTidAcc / setTidAcc', () {
    test('set and get tidal acceleration', () {
      final original = swe.getTidAcc();
      swe.setTidAcc(25.82);
      expect(swe.getTidAcc(), closeTo(25.82, 0.001));
      // Restore
      swe.setTidAcc(original);
    });

    test('user-defined delta T overrides automatic', () {
      final auto = swe.deltat(2451545.0);
      swe.setDeltaTUserdef(0.001); // 0.001 days = 86.4 seconds
      final userDef = swe.deltat(2451545.0);
      expect(userDef, closeTo(0.001, 1e-10));
      // Restore automatic
      swe.setDeltaTUserdef(-1e-10);
      final restored = swe.deltat(2451545.0);
      expect(restored, closeTo(auto, 1e-10));
    });
  });

  group('splitDeg', () {
    test('split with zodiacal flag', () {
      // 123.456° = 3° Cancer 27'
      final result = swe.splitDeg(123.456, seSplitDegRoundSec | seSplitDegZodiacal);
      expect(result.degrees, equals(3));
      expect(result.minutes, equals(27));
      expect(result.sign, equals(4)); // Cancer = sign 4 (1-indexed)
    });
  });

  group('sidTime0', () {
    test('sidTime0 with explicit obliquity and nutation', () {
      // Should return a valid sidereal time value
      final gst = swe.sidTime0(2451545.0, 23.44, -0.005);
      expect(gst, greaterThan(0));
      expect(gst, lessThan(24));
    });
  });
}
