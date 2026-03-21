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

  group('houses', () {
    test('Campanus houses at J2000 noon, Washington DC', () {
      final jd = swe.julday(2000, 1, 1, 12.0);
      final result = swe.houses(jd, 38.8977, -77.0365, hsysCampanus);
      expect(result.cusps[1], closeTo(272.731, 0.001));
      expect(result.cusps[4], closeTo(25.273, 0.001));
      expect(result.cusps[7], closeTo(92.731, 0.001));
      expect(result.cusps[10], closeTo(205.273, 0.001));
      expect(result.ascendant, closeTo(272.731, 0.001));
      expect(result.mc, closeTo(205.273, 0.001));
      expect(result.armc, closeTo(203.421, 0.001));
      expect(result.vertex, closeTo(133.066, 0.001));
    });

    test('Whole Sign houses have 30-degree spacing from Asc sign', () {
      final jd = swe.julday(2000, 1, 1, 12.0);
      final result = swe.houses(jd, 38.8977, -77.0365, hsysWholeSign);
      final signStart = (result.ascendant ~/ 30) * 30.0;
      expect(result.cusps[1], closeTo(signStart, 0.001));
      for (var i = 2; i <= 12; i++) {
        final expected = (signStart + (i - 1) * 30.0) % 360.0;
        expect(result.cusps[i], closeTo(expected, 0.001));
      }
    });

    test('cusps list has 13 elements (index 0 unused)', () {
      final jd = swe.julday(2000, 1, 1, 12.0);
      final result = swe.houses(jd, 38.8977, -77.0365, hsysCampanus);
      expect(result.cusps.length, equals(13));
    });

    test('ascmc list has 10 elements', () {
      final jd = swe.julday(2000, 1, 1, 12.0);
      final result = swe.houses(jd, 38.8977, -77.0365, hsysCampanus);
      expect(result.ascmc.length, equals(10));
    });
  });
}
