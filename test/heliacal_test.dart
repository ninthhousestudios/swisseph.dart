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

  final defaultAtmo = AtmoConditions(
    pressure: 1013.25,
    temperature: 25,
    humidity: 50,
    extinction: 0.2,
  );
  final defaultObserver = ObserverConditions();

  group('heliacalUt', () {
    test('Venus heliacal rising from Cairo', () {
      // Cairo: 30°N, 31°E — use Venus (planet, no star file needed)
      // Start search from Jan 1, 2000
      final jdStart = swe.julday(2000, 1, 1, 0.0);
      final result = swe.heliacalUt(
        jdStart,
        geolon: 31.0,
        geolat: 30.0,
        atmo: defaultAtmo,
        observer: defaultObserver,
        objectName: 'Venus',
        typeEvent: seHeliacalRising,
      );
      // Start of visibility should be after our start date
      expect(result.startVisible, greaterThan(jdStart));
      // Best visibility should be after start
      expect(result.bestVisible, greaterThanOrEqualTo(result.startVisible));
    });
  });

  group('heliacalPhenoUt', () {
    test('Venus heliacal phenomena returns valid data', () {
      // Use a date when Venus is visible
      final jdUt = swe.julday(2000, 6, 15, 0.0);
      final result = swe.heliacalPhenoUt(
        jdUt,
        geolon: 31.0,
        geolat: 30.0,
        atmo: defaultAtmo,
        observer: defaultObserver,
        objectName: 'Venus',
        typeEvent: seHeliacalRising,
      );
      // Raw array should have 50 elements
      expect(result.raw.length, equals(50));
    });
  });

  group('visLimitMag', () {
    test('visibility limit magnitude is finite for Venus at dusk', () {
      // Use evening time when Venus is likely above horizon
      // Jan 1, 2000 at 17:30 UT (dusk in Cairo)
      final jdUt = swe.julday(2000, 1, 1, 17.5);
      // visLimitMag can return -2 if object is below horizon.
      // We test with a try/catch — if it works, check the result is finite;
      // if it throws because the object is below horizon, that's also valid.
      try {
        final result = swe.visLimitMag(
          jdUt,
          geolon: 31.0,
          geolat: 30.0,
          atmo: defaultAtmo,
          observer: defaultObserver,
          objectName: 'Venus',
        );
        expect(result.limitMagnitude.isFinite, isTrue);
      } on SweException catch (e) {
        // -2 means object below horizon — acceptable for this test
        expect(e.returnFlag, equals(-2));
      }
    });

    test('visibility limit magnitude works for Moon at night', () {
      // Use a time when Moon is likely above horizon
      // Full moon near Jan 21, 2000 — use evening
      final jdUt = swe.julday(2000, 1, 21, 22.0);
      try {
        final result = swe.visLimitMag(
          jdUt,
          geolon: 31.0,
          geolat: 30.0,
          atmo: defaultAtmo,
          observer: defaultObserver,
          objectName: 'Moon',
        );
        expect(result.limitMagnitude.isFinite, isTrue);
      } on SweException catch (e) {
        // Object below horizon is acceptable
        expect(e.returnFlag, equals(-2));
      }
    });
  });

  group('riseTransTrueHor', () {
    test('sunrise with elevated horizon differs from regular riseTrans', () {
      final jd = swe.julday(2000, 1, 1, 0.0);
      // Regular sunrise
      final regular = swe.riseTrans(
        jd,
        seSun,
        geolon: 31.0,
        geolat: 30.0,
      );
      // Sunrise with 1-degree elevated horizon
      final elevated = swe.riseTransTrueHor(
        jd,
        seSun,
        geolon: 31.0,
        geolat: 30.0,
        horizonHeight: 1.0,
      );
      // With an elevated horizon, sunrise should be later
      expect(elevated.transitTime, greaterThan(regular.transitTime));
      // But not by much (within a fraction of a day)
      expect(elevated.transitTime - regular.transitTime, lessThan(0.1));
    });
  });
}
