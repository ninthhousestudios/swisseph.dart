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

  group('calcUt', () {
    test('Sun position at J2000 (Moshier)', () {
      final jd = swe.julday(2000, 1, 1, 0.0);
      final result = swe.calcUt(jd, seSun, seflgMoseph | seflgSpeed);
      expect(result.longitude, closeTo(279.858, 0.01));
      expect(result.longitudeSpeed, closeTo(1.019, 0.01));
    });

    test('Moon position at J2000 (Moshier)', () {
      final jd = swe.julday(2000, 1, 1, 0.0);
      final result = swe.calcUt(jd, seMoon, seflgMoseph | seflgSpeed);
      expect(result.longitude, closeTo(217.284, 0.01));
      expect(result.longitudeSpeed, closeTo(12.103, 0.01));
    });

    test('all classical planets return valid longitudes', () {
      final jd = swe.julday(2000, 1, 1, 0.0);
      for (final body in [
        seSun, seMoon, seMercury, seVenus, seMars, seJupiter, seSaturn
      ]) {
        final result = swe.calcUt(jd, body, seflgMoseph | seflgSpeed);
        expect(result.longitude, greaterThanOrEqualTo(0.0));
        expect(result.longitude, lessThan(360.0));
        expect(result.returnFlag, isNonNegative,
            reason: 'Negative return flag indicates error for body $body');
      }
    });

    test('returns error string for invalid body', () {
      final jd = swe.julday(2000, 1, 1, 0.0);
      expect(
        () => swe.calcUt(jd, -2, seflgMoseph),
        throwsA(isA<SweException>()),
      );
    });
  });

  group('riseTrans', () {
    test('sunrise at Washington DC on J2000', () {
      final jd = swe.julday(2000, 1, 1, 0.0);
      final result = swe.riseTrans(
        jd,
        seSun,
        rsmi: seCalcRise,
        geolon: -77.0365,
        geolat: 38.8977,
      );
      expect(result.transitTime, greaterThan(jd));
      expect(result.transitTime, lessThan(jd + 1));
    });
  });
}
