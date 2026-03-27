import 'package:test/test.dart';
import 'package:swisseph/swisseph.dart';

void main() {
  test('SwissEph.load() async factory works on native', () async {
    final swe = await SwissEph.load();
    expect(swe.version(), isNotEmpty);
    swe.close();
  });
}
