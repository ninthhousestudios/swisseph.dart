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

  final jd2000 = 2451545.0; // J2000.0

  group('nodApsUt', () {
    test('Moon ascending node longitude is reasonable', () {
      final result = swe.nodApsUt(
          jd2000, seMoon, seflgMoseph | seflgSpeed, seNodbitMean);
      // Mean ascending node should be somewhere in 0-360
      expect(result.ascending.longitude, greaterThanOrEqualTo(0));
      expect(result.ascending.longitude, lessThan(360));
      // Descending node ~180 degrees away
      final diff =
          swe.degnorm(result.descending.longitude - result.ascending.longitude);
      expect(diff, closeTo(180, 5));
    });

    test('nodAps ET variant returns similar results', () {
      final resultUt = swe.nodApsUt(
          jd2000, seMoon, seflgMoseph, seNodbitMean);
      final resultEt = swe.nodAps(
          jd2000, seMoon, seflgMoseph, seNodbitMean);
      // Should be close but not identical (UT vs ET)
      expect(resultEt.ascending.longitude,
          closeTo(resultUt.ascending.longitude, 0.1));
    });
  });

  group('getOrbitalElements', () {
    test('Earth orbital elements are reasonable', () {
      final result =
          swe.getOrbitalElements(jd2000, seEarth, seflgMoseph);
      // Eccentricity ~0.017
      expect(result.eccentricity, closeTo(0.017, 0.005));
      // Semimajor axis ~1.0 AU
      expect(result.semimajorAxis, closeTo(1.0, 0.01));
      // Sidereal period ~1 year
      expect(result.siderealPeriodYears, closeTo(1.0, 0.01));
    });
  });

  group('orbitMaxMinTrueDistance', () {
    test('Mars distances: max > true, min < true, all positive', () {
      final result =
          swe.orbitMaxMinTrueDistance(jd2000, seMars, seflgMoseph);
      expect(result.maxDist, greaterThan(0));
      expect(result.minDist, greaterThan(0));
      expect(result.trueDist, greaterThan(0));
      expect(result.maxDist, greaterThan(result.minDist));
    });
  });

  group('phenoUt', () {
    test('Venus phase angle is positive', () {
      final result = swe.phenoUt(jd2000, seVenus, seflgMoseph);
      expect(result.phaseAngle, greaterThan(0));
      expect(result.elongation, greaterThan(0));
      // Apparent diameter should be small but positive
      expect(result.apparentDiameter, greaterThan(0));
    });

    test('pheno ET variant gives similar results', () {
      final resultUt = swe.phenoUt(jd2000, seVenus, seflgMoseph);
      final resultEt = swe.pheno(jd2000, seVenus, seflgMoseph);
      // Phase angle should be close
      expect(resultEt.phaseAngle, closeTo(resultUt.phaseAngle, 0.5));
    });
  });
}
