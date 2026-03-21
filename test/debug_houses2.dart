import 'package:swisseph/swisseph.dart';

void main() {
  final swe = SwissEph.find();
  final jd = swe.julday(2000, 1, 1, 12.0);
  print('JD: $jd');
  final r = swe.houses(jd, 38.8977, -77.0365, hsysCampanus);
  print('Asc: ${r.ascendant}');
  print('MC: ${r.mc}');
  print('ARMC: ${r.armc}');
  print('Vertex: ${r.vertex}');
  for (var i = 1; i <= 12; i++) {
    print('cusps[$i]: ${r.cusps[i]}');
  }
  swe.close();
}
