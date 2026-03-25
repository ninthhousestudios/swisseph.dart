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

  group('ayanamsa', () {
    test('Lahiri ayanamsa at J2000', () {
      swe.setSidMode(seSidmLahiri);
      final jd = swe.julday(2000, 1, 1, 0.0);
      final aya = swe.getAyanamsaUt(jd);
      expect(aya, closeTo(23.853, 0.01));
    });

    test('ayanamsa name for Lahiri', () {
      final name = swe.getAyanamsaName(seSidmLahiri);
      expect(name.toLowerCase(), contains('lahiri'));
    });

    test('sidereal position = tropical - ayanamsa', () {
      swe.setSidMode(seSidmLahiri);
      final jd = swe.julday(2000, 1, 1, 0.0);
      final tropical = swe.calcUt(jd, seSun, seFlgMosEph | seFlgSpeed);
      final sidereal = swe.calcUt(
          jd, seSun, seFlgMosEph | seFlgSpeed | seFlgSidereal);
      final aya = swe.getAyanamsaUt(jd);
      final expected = (tropical.longitude - aya) % 360;
      expect(sidereal.longitude, closeTo(expected, 0.01));
    });

    test('getAyanamsaExUt returns consistent value across calls', () {
      swe.setSidMode(seSidmLahiri);
      final jd = swe.julday(2000, 1, 1, 0.0);
      final first = swe.getAyanamsaExUt(jd, seFlgMosEph);
      final second = swe.getAyanamsaExUt(jd, seFlgMosEph);
      expect(second.ayanamsa, equals(first.ayanamsa));
      // Moshier ayanamsa should be close to the expected Lahiri value
      expect(first.ayanamsa, closeTo(23.853, 0.01));
    });
  });
}
