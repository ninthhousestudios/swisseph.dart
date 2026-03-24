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

  group('utcToJd', () {
    test('J2000.0 epoch returns correct ET and UT1', () {
      final result = swe.utcToJd(2000, 1, 1, 12, 0, 0.0);
      // J2000.0 UT1 should be 2451545.0
      expect(result.ut1, closeTo(2451545.0, 0.001));
      // ET differs from UT1 by delta-T (~63.8 seconds in 2000)
      expect(result.et, greaterThan(result.ut1));
      expect(result.et, closeTo(2451545.0, 0.01));
    });

    test('invalid date throws SweException', () {
      expect(
        () => swe.utcToJd(2000, 13, 1, 12, 0, 0.0),
        throwsA(isA<SweException>()),
      );
    });
  });

  group('jdToUtc', () {
    test('roundtrip through utcToJd', () {
      // Convert a known UTC date to JD, then back
      final jdPair = swe.utcToJd(2000, 1, 1, 12, 0, 0.0);
      final result = swe.jdToUtc(jdPair.ut1);
      expect(result.year, equals(2000));
      expect(result.month, equals(1));
      expect(result.day, equals(1));
      expect(result.hour, equals(12));
      expect(result.min, equals(0));
      expect(result.sec, closeTo(0.0, 0.1));
    });
  });

  group('jdetToUtc', () {
    test('convert known ET JD back to UTC', () {
      // First get the ET JD for a known date
      final jdPair = swe.utcToJd(2000, 1, 1, 12, 0, 0.0);
      // Convert the ET JD back — should recover the original date
      final result = swe.jdetToUtc(jdPair.et);
      expect(result.year, equals(2000));
      expect(result.month, equals(1));
      expect(result.day, equals(1));
      expect(result.hour, equals(12));
      expect(result.min, equals(0));
      expect(result.sec, closeTo(0.0, 0.1));
    });
  });

  group('utcTimeZone', () {
    test('convert UTC to EST (timezone = -5)', () {
      // 2000-01-01 17:00:00 UTC should be 2000-01-01 12:00:00 EST
      // utcTimeZone subtracts the timezone offset, so to go from UTC to EST:
      // input UTC time with timezone = -5 gives local EST time
      // Actually: swe_utc_time_zone converts FROM local TO UTC.
      // So input local EST 12:00 with tz=-5 should give UTC 17:00.
      final result = swe.utcTimeZone(2000, 1, 1, 12, 0, 0.0, -5.0);
      expect(result.year, equals(2000));
      expect(result.month, equals(1));
      expect(result.day, equals(1));
      expect(result.hour, equals(17));
      expect(result.min, equals(0));
      expect(result.sec, closeTo(0.0, 0.001));
    });
  });

  group('dateConversion', () {
    test('valid date returns Julian Day', () {
      final jd = swe.dateConversion(2000, 1, 1, 12.0);
      expect(jd, isNotNull);
      expect(jd, closeTo(2451545.0, 0.001));
    });

    test('invalid date (Feb 30) returns null', () {
      final jd = swe.dateConversion(2000, 2, 30, 12.0);
      expect(jd, isNull);
    });
  });

  group('dayOfWeek', () {
    test('2000-01-01 (J2000) is Saturday = 5', () {
      // J2000.0 = 2000-01-01 12:00 UT, which is a Saturday
      // swe_day_of_week: 0=Monday, ..., 5=Saturday, 6=Sunday
      final dow = swe.dayOfWeek(2451545.0);
      expect(dow, equals(5));
    });
  });

  group('getLibraryPath', () {
    test('returns a non-empty string', () {
      final path = swe.getLibraryPath();
      expect(path, isNotEmpty);
    });
  });

  group('getCurrentFileData', () {
    test('fileNum=0 returns a result', () {
      // With Moshier ephemeris, path may be null but should not throw
      final result = swe.getCurrentFileData(0);
      expect(result, isNotNull);
      // ephemerisNumber should be a valid value
      expect(result.ephemerisNumber, isA<int>());
    });
  });
}
