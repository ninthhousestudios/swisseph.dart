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

  // J2000 epoch
  final jdUt = 2451545.0; // 2000-01-01 12:00 UT
  // Location: London
  const geolat = 51.5;
  const geolon = -0.1167;

  test('calc — Sun position at J2000 ET close to calcUt result', () {
    // ET and UT differ by ~63 seconds at J2000, so positions should be close
    // but not identical.
    final utResult = swe.calcUt(jdUt, seSun, seFlgSwiEph | seFlgSpeed);
    final etResult = swe.calc(jdUt, seSun, seFlgSwiEph | seFlgSpeed);
    // Longitude should be within ~1 arcminute (Sun moves ~1 degree/day,
    // 63 seconds ~ 0.001 degree)
    expect((etResult.longitude - utResult.longitude).abs(), lessThan(0.02));
    // Both should have nonzero speed
    expect(utResult.longitudeSpeed, isNonZero);
    expect(etResult.longitudeSpeed, isNonZero);
  });

  test('housesEx — matches houses() when flags=0', () {
    final h = swe.houses(jdUt, geolat, geolon, hsysPlacidus);
    final hEx = swe.housesEx(jdUt, 0, geolat, geolon, hsysPlacidus);
    // Cusps should be identical
    for (var i = 1; i <= 12; i++) {
      expect(hEx.cusps[i], closeTo(h.cusps[i], 1e-10),
          reason: 'cusp $i mismatch');
    }
    // Ascmc should be identical
    for (var i = 0; i < 8; i++) {
      expect(hEx.ascmc[i], closeTo(h.ascmc[i], 1e-10),
          reason: 'ascmc[$i] mismatch');
    }
  });

  test('housesEx2 — cusp speeds are nonzero for Placidus', () {
    final hEx2 = swe.housesEx2(jdUt, 0, geolat, geolon, hsysPlacidus);
    // Cusps should be valid
    expect(hEx2.cusps.length, 13);
    expect(hEx2.ascmc.length, 10);
    expect(hEx2.cuspSpeeds.length, 13);
    expect(hEx2.ascmcSpeeds.length, 10);
    // At least some cusp speeds should be nonzero
    var anyNonZero = false;
    for (var i = 1; i <= 12; i++) {
      if (hEx2.cuspSpeeds[i] != 0.0) anyNonZero = true;
    }
    expect(anyNonZero, isTrue, reason: 'all cusp speeds are zero');
    // Ascendant speed should be nonzero
    expect(hEx2.ascendantSpeed, isNonZero);
    // Convenience getters
    expect(hEx2.ascendant, hEx2.ascmc[0]);
    expect(hEx2.mc, hEx2.ascmc[1]);
    expect(hEx2.armc, hEx2.ascmc[2]);
    expect(hEx2.vertex, hEx2.ascmc[3]);
  });

  test('housesArmc — cusps match houses() for same ARMC', () {
    // Get ARMC and obliquity from houses()
    final h = swe.houses(jdUt, geolat, geolon, hsysPlacidus);
    final armc = h.armc;
    // Compute obliquity: calcUt for the Earth's obliquity
    // swe_calc_ut with SE_ECL_NUT (body=-1) returns obliquity in xx[0]
    // But we can approximate eps from the houses result.
    // Actually, let's compute it properly. The true obliquity can be retrieved
    // by computing the ecliptic/nutation (special body -1).
    const seEclNut = -1;
    final eclResult = swe.calcUt(jdUt, seEclNut, 0);
    final eps = eclResult.longitude; // true obliquity

    final hArmc = swe.housesArmc(armc, geolat, eps, hsysPlacidus);
    // Cusps should match closely
    for (var i = 1; i <= 12; i++) {
      expect(hArmc.cusps[i], closeTo(h.cusps[i], 0.001),
          reason: 'cusp $i mismatch');
    }
  });

  test('housePos — Sun is in a valid house', () {
    final h = swe.houses(jdUt, geolat, geolon, hsysPlacidus);
    final sun = swe.calcUt(jdUt, seSun, seFlgSwiEph);
    const seEclNut = -1;
    final eclResult = swe.calcUt(jdUt, seEclNut, 0);
    final eps = eclResult.longitude;

    final pos = swe.housePos(
        h.armc, geolat, eps, hsysPlacidus, sun.longitude, sun.latitude);
    // Should be between 1.0 and 13.0 (exclusive)
    expect(pos, greaterThanOrEqualTo(1.0));
    expect(pos, lessThan(13.0));
  });

  test('gauquelinSector — returns value between 1 and 36', () {
    final sector = swe.gauquelinSector(
      jdUt,
      seSun,
      seFlgSwiEph,
      0, // method: sector from rise/set
      geolon: geolon,
      geolat: geolat,
    );
    expect(sector, greaterThanOrEqualTo(1.0));
    expect(sector, lessThanOrEqualTo(36.0));
  });
}
