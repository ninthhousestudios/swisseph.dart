import 'dart:io';
import 'package:test/test.dart';
import 'package:swisseph/swisseph.dart';

void main() {
  late SwissEph swe;

  setUp(() {
    swe = SwissEph.find();
    // Fixed star functions need access to sefstars.txt
    final ephePath = '${Directory.current.path}/ephe';
    swe.setEphePath(ephePath);
  });

  tearDown(() {
    swe.close();
  });

  group('fixstar2Ut', () {
    test('Sirius longitude is reasonable', () {
      final jd = swe.julday(2000, 1, 1, 12.0);
      final result = swe.fixstar2Ut('Sirius', jd, seFlgMosEph);
      // Sirius ecliptic longitude is around 104° (Cancer ~14°)
      expect(result.longitude, closeTo(104.0, 1.0));
    });

    test('returned starName contains Sirius', () {
      final jd = swe.julday(2000, 1, 1, 12.0);
      final result = swe.fixstar2Ut('Sirius', jd, seFlgMosEph);
      expect(result.starName.toLowerCase(), contains('sirius'));
    });
  });

  group('fixstar2', () {
    test('Sirius via ET variant returns similar longitude', () {
      final jd = swe.julday(2000, 1, 1, 12.0);
      final utResult = swe.fixstar2Ut('Sirius', jd, seFlgMosEph);
      final etResult = swe.fixstar2('Sirius', jd, seFlgMosEph);
      // ET and UT differ by delta-T (~64s in 2000), so longitudes should be very close
      expect(etResult.longitude, closeTo(utResult.longitude, 0.01));
    });
  });

  group('fixstar2Mag', () {
    test('Sirius magnitude is around -1.46', () {
      final mag = swe.fixstar2Mag('Sirius');
      expect(mag, closeTo(-1.46, 0.1));
    });
  });
}
