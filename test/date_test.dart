import 'dart:io';
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

  group('version', () {
    test('returns a non-empty version string', () {
      final v = swe.version();
      expect(v, isNotEmpty);
      expect(v, contains('.'));
    });
  });

  group('julday', () {
    test('J2000.0 epoch', () {
      final jd = swe.julday(2000, 1, 1, 12.0);
      expect(jd, equals(2451545.0));
    });

    test('known date: 1985-01-01 00:00', () {
      final jd = swe.julday(1985, 1, 1, 0.0);
      expect(jd, equals(2446066.5));
    });
  });

  group('revjul', () {
    test('J2000.0 epoch roundtrip', () {
      final result = swe.revjul(2451545.0);
      expect(result.year, equals(2000));
      expect(result.month, equals(1));
      expect(result.day, equals(1));
      expect(result.hour, closeTo(12.0, 1e-10));
    });

    test('julday/revjul roundtrip', () {
      final jd = swe.julday(1990, 6, 15, 18.5);
      final result = swe.revjul(jd);
      expect(result.year, equals(1990));
      expect(result.month, equals(6));
      expect(result.day, equals(15));
      // swe_revjul has ~1e-8 precision on the hour field due to double-precision
      // floating point through the JD conversion; 1e-6 is sub-millisecond.
      expect(result.hour, closeTo(18.5, 1e-6));
    });
  });
}
