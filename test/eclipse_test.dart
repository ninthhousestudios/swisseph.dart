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

  group('Solar eclipses', () {
    test('solEclipseWhenGlob finds April 8 2024 total solar eclipse', () {
      final jdStart = swe.julday(2024, 1, 1, 0.0);
      final result = swe.solEclipseWhenGlob(jdStart, seFlgMosEph);

      // The next solar eclipse after Jan 1 2024 is April 8 2024 (total)
      final date = swe.revjul(result.maxEclipse);
      expect(date.year, equals(2024));
      expect(date.month, equals(4));
      expect(date.day, equals(8));

      // Should be flagged as total
      expect(result.returnFlag & seEclTotal, isNonZero);

      // Timing sanity: begin < max < end
      expect(result.begin, lessThan(result.maxEclipse));
      expect(result.maxEclipse, lessThan(result.end));
    });

    test('solEclipseWhenLoc from Dallas TX', () {
      final jdStart = swe.julday(2024, 1, 1, 0.0);
      final result = swe.solEclipseWhenLoc(jdStart, seFlgMosEph,
          geolon: -96.80, geolat: 32.78);

      // Should find the April 8 2024 eclipse
      final date = swe.revjul(result.maxEclipse);
      expect(date.year, equals(2024));
      expect(date.month, equals(4));
      expect(date.day, equals(8));

      // Timing order: firstContact < secondContact < maxEclipse < thirdContact < fourthContact
      expect(result.firstContact, lessThan(result.maxEclipse));
      expect(result.maxEclipse, lessThan(result.fourthContact));

      // secondContact and thirdContact may be 0 if not total at this location,
      // but if nonzero they should bracket maxEclipse
      if (result.secondContact > 0 && result.thirdContact > 0) {
        expect(result.secondContact, lessThan(result.maxEclipse));
        expect(result.maxEclipse, lessThan(result.thirdContact));
      }

      // Magnitude should be positive
      expect(result.magnitude, greaterThan(0));
    });

    test('solEclipseHow at time/location from Dallas', () {
      final jdStart = swe.julday(2024, 1, 1, 0.0);
      final local = swe.solEclipseWhenLoc(jdStart, seFlgMosEph,
          geolon: -96.80, geolat: 32.78);

      final result = swe.solEclipseHow(local.maxEclipse, seFlgMosEph,
          geolon: -96.80, geolat: 32.78);

      // Magnitude should be positive
      expect(result.magnitude, greaterThan(0));

      // Sun azimuth should be a valid angle (0-360)
      expect(result.sunAzimuth, greaterThanOrEqualTo(0));
      expect(result.sunAzimuth, lessThan(360));
    });

    test('solEclipseWhere finds central line in reasonable location', () {
      // First find the eclipse time
      final jdStart = swe.julday(2024, 1, 1, 0.0);
      final glob = swe.solEclipseWhenGlob(jdStart, seFlgMosEph);

      // Get the central line location at maximum eclipse
      final result = swe.solEclipseWhere(glob.maxEclipse, seFlgMosEph);

      // The April 8 2024 eclipse path crosses North America
      // Latitude should be roughly 15-50N, longitude roughly -120 to -40W
      expect(result.geolat, greaterThan(10));
      expect(result.geolat, lessThan(55));
      expect(result.geolon, greaterThan(-130));
      expect(result.geolon, lessThan(-30));

      // Magnitude should be positive
      expect(result.magnitude, greaterThan(0));
    });
  });

  group('Lunar eclipses', () {
    test('lunEclipseWhen finds March 25 2024 penumbral lunar eclipse', () {
      final jdStart = swe.julday(2024, 1, 1, 0.0);
      final result = swe.lunEclipseWhen(jdStart, seFlgMosEph);

      final date = swe.revjul(result.maxEclipse);
      expect(date.year, equals(2024));
      expect(date.month, equals(3));
      expect(date.day, equals(25));

      // Should be penumbral
      expect(result.returnFlag & seEclPenumbral, isNonZero);

      // Penumbral begin/end should bracket max
      expect(result.penumbralBegin, lessThan(result.maxEclipse));
      expect(result.maxEclipse, lessThan(result.penumbralEnd));
    });

    test('lunEclipseHow for March 25 2024 eclipse', () {
      final jdStart = swe.julday(2024, 1, 1, 0.0);
      final when = swe.lunEclipseWhen(jdStart, seFlgMosEph);

      // Get attributes from a location that can see it (e.g. London)
      final result = swe.lunEclipseHow(when.maxEclipse, seFlgMosEph,
          geolon: -0.12, geolat: 51.51);

      // For a penumbral eclipse, penumbral magnitude should be positive
      expect(result.penumbralMagnitude, greaterThan(0));
    });
  });
}
