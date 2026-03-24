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

  group('solCrossUt', () {
    test('Sun crosses 0° (vernal equinox) near March 20 2000', () {
      // Start from Jan 1 2000
      final jdStart = swe.julday(2000, 1, 1, 0.0);
      final jdCross = swe.solCrossUt(0.0, jdStart, seflgMoseph);
      // Vernal equinox 2000 was around March 20
      final date = swe.revjul(jdCross);
      expect(date.year, equals(2000));
      expect(date.month, equals(3));
      expect(date.day, closeTo(20, 1));
    });
  });

  group('moonCrossUt', () {
    test('Moon crosses 0° Aries starting from a known date', () {
      final jdStart = swe.julday(2000, 1, 1, 0.0);
      final jdCross = swe.moonCrossUt(0.0, jdStart, seflgMoseph);
      // Should find a crossing within ~28 days
      expect(jdCross, greaterThan(jdStart));
      expect(jdCross, lessThan(jdStart + 30));
    });
  });

  group('moonCrossNodeUt', () {
    test('finds next node crossing with longitude near 0° or 180°', () {
      final jdStart = swe.julday(2000, 1, 1, 0.0);
      final result = swe.moonCrossNodeUt(jdStart, seflgMoseph);
      // The crossing JD should be after start
      expect(result.jdUt, greaterThan(jdStart));
      // At a node crossing, the Moon's latitude should be near 0°
      expect(result.latitude.abs(), lessThan(1.0));
    });
  });

  group('getAyanamsa ET variants', () {
    test('getAyanamsa at J2000 approximately matches getAyanamsaUt', () {
      final jd = swe.julday(2000, 1, 1, 12.0);
      swe.setSidMode(seSidmLahiri);
      final ayaUt = swe.getAyanamsaUt(jd);
      final ayaEt = swe.getAyanamsa(jd);
      // ET and UT differ by delta-T (~64s), so ayanamsas should be very close
      expect(ayaEt, closeTo(ayaUt, 0.001));
    });

    test('getAyanamsaEx returns same as getAyanamsa', () {
      final jd = swe.julday(2000, 1, 1, 12.0);
      swe.setSidMode(seSidmLahiri);
      final ayaSimple = swe.getAyanamsa(jd);
      final ayaEx = swe.getAyanamsaEx(jd, seflgMoseph);
      expect(ayaEx.ayanamsa, closeTo(ayaSimple, 0.01));
    });
  });
}
