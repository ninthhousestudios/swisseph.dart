import 'package:swisseph/swisseph.dart';

void main() {
  final swe = SwissEph.find();

  print('Swiss Ephemeris v${swe.version()}');
  print('');

  // Calculate Sun and Moon positions for 2000-01-01 12:00 UT
  final jd = swe.julday(2000, 1, 1, 12.0);
  print('Julian Day: $jd (J2000.0 epoch)');
  print('');

  // Tropical positions (Moshier — no data files needed)
  final sun = swe.calcUt(jd, seSun, seflgMoseph | seflgSpeed);
  final moon = swe.calcUt(jd, seMoon, seflgMoseph | seflgSpeed);
  print('Tropical positions:');
  print('  ${swe.getPlanetName(seSun)}: ${sun.longitude.toStringAsFixed(4)}°'
      ' (speed: ${sun.longitudeSpeed.toStringAsFixed(4)}°/day)');
  print('  ${swe.getPlanetName(seMoon)}: ${moon.longitude.toStringAsFixed(4)}°'
      ' (speed: ${moon.longitudeSpeed.toStringAsFixed(4)}°/day)');
  print('');

  // Sidereal (Lahiri) positions
  swe.setSidMode(seSidmLahiri);
  final aya = swe.getAyanamsaUt(jd);
  final sidSun = swe.calcUt(jd, seSun, seflgMoseph | seflgSpeed | seflgSidereal);
  print('Lahiri ayanamsa: ${aya.toStringAsFixed(4)}°');
  print('Sidereal Sun: ${sidSun.longitude.toStringAsFixed(4)}°');
  print('');

  // House cusps (Campanus, Washington DC)
  final houses = swe.houses(jd, 38.8977, -77.0365, hsysCampanus);
  print('Campanus houses (Washington DC):');
  for (var i = 1; i <= 12; i++) {
    print('  House $i: ${houses.cusps[i].toStringAsFixed(4)}°');
  }
  print('  Ascendant: ${houses.ascendant.toStringAsFixed(4)}°');
  print('  MC: ${houses.mc.toStringAsFixed(4)}°');

  swe.close();
}
