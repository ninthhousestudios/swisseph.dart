@Tags(['stress'])
@Timeout(Duration(minutes: 180))
library;

import 'dart:io';
import 'dart:isolate';
import 'package:test/test.dart';
import 'package:swisseph/swisseph.dart';

// ---------------------------------------------------------------------------
// Pre-built valid parameter space.
// Every combination here is known-valid — no runtime bounds checking.
// ---------------------------------------------------------------------------

/// Geocentric bodies for Moshier: Sun through OscuApog (0–13).
/// Skips Earth (14) — meaningless geocentric.
/// Skips Chiron (15) — Moshier restricts to JD 1967601–3419437 (~675–3000 CE).
const List<int> moshierGeocentricBodies = [
  seSun, seMoon, seMercury, seVenus, seMars, seJupiter, seSaturn,
  seUranus, seNeptune, sePluto, seMeanNode, seTrueNode, seMeanApog,
  seOscuApog,
];

/// Geocentric bodies for SwissEph: same as Moshier.
const List<int> sweGeocentricBodies = [
  seSun, seMoon, seMercury, seVenus, seMars, seJupiter, seSaturn,
  seUranus, seNeptune, sePluto, seMeanNode, seTrueNode, seMeanApog,
  seOscuApog,
];

/// Heliocentric bodies: planets only. Includes Earth (14).
const List<int> helioBodies = [
  seMercury, seVenus, seMars, seJupiter, seSaturn,
  seUranus, seNeptune, sePluto, seEarth,
];

/// Barycentric bodies (SwissEph only). Sun + planets.
const List<int> baryBodies = [
  seSun, seMercury, seVenus, seMars, seJupiter, seSaturn,
  seUranus, seNeptune, sePluto, seEarth,
];

/// All 47 standard ayanamsa modes.
const List<int> stdAyanamsas = [
  seSidmFaganBradley, seSidmLahiri, seSidmDeluce, seSidmRaman,
  seSidmUshashashi, seSidmKrishnamurti, seSidmDjwhalKhul,
  seSidmYukteshwar, seSidmJnBhasin, seSidmBabylKugler1,
  seSidmBabylKugler2, seSidmBabylKugler3, seSidmBabylHuber,
  seSidmBabylEtpsc, seSidmAldebaran15tau, seSidmHipparchos,
  seSidmSassanian, seSidmGalcent0sag, seSidmJ2000, seSidmJ1900,
  seSidmB1950, seSidmSuryasiddhanta, seSidmSuryasiddhantaMsun,
  seSidmAryabhata, seSidmAryabhataMsun, seSidmSsRevati, seSidmSsCitra,
  seSidmTrueCitra, seSidmTrueRevati, seSidmTruePushya,
  seSidmGalcentRgilbrand, seSidmGalequIau1958, seSidmGalequTrue,
  seSidmGalequMula, seSidmGalalignMardyks, seSidmTrueMula,
  seSidmGalcentMulaWilhelm, seSidmAryabhata522, seSidmBabylBritton,
  seSidmTrueSheoran, seSidmGalcentCochrane, seSidmGalequFiorenza,
  seSidmValensMoon, seSidmLahiri1940, seSidmLahiriVp285,
  seSidmKrishnamurtiVp291, seSidmLahiriIcrc,
];

/// Five user-defined ayanamsas (seSidmUser = 255).
const List<({double t0, double ayanT0})> userDefinedAyanamsas = [
  (t0: 2451545.0, ayanT0: 23.5),   // J2000, ~Lahiri-ish
  (t0: 2415020.5, ayanT0: 22.37),  // J1900
  (t0: 2400000.0, ayanT0: 20.0),   // ~1858
  (t0: 2451545.0, ayanT0: 0.0),    // zero ayanamsa at J2000
  (t0: 2451545.0, ayanT0: 50.0),   // extreme offset
];

/// House systems (11 standard).
const List<int> houseSystemList = [
  hsysPlacidus, hsysKoch, hsysPorphyry, hsysRegiomontanus,
  hsysCampanus, hsysEqual, hsysWholeSign, hsysAlcabitius,
  hsysTopocentric, hsysMeridian, hsysMorinus,
];

/// Geographic locations: (lat, lon) pairs.
const List<(double, double)> locations = [
  (28.6139, 77.2090),    // Delhi
  (51.5074, -0.1278),    // London
  (40.7128, -74.0060),   // New York
  (-33.8688, 151.2093),  // Sydney
  (35.6762, 139.6503),   // Tokyo
  (0.0, 0.0),            // Null Island
  (-22.9068, -43.1729),  // Rio de Janeiro
  (70.0, 25.0),          // Hammerfest, Norway (polar)
];

/// Non-polar locations only — safe for all house systems.
const List<(double, double)> nonPolarLocations = [
  (28.6139, 77.2090),
  (51.5074, -0.1278),
  (40.7128, -74.0060),
  (-33.8688, 151.2093),
  (35.6762, 139.6503),
  (0.0, 0.0),
  (-22.9068, -43.1729),
];

/// Fixed stars for fixstar2 workload.
const List<String> fixedStars = [
  'Sirius', 'Aldebaran', 'Regulus', 'Spica', 'Antares',
  'Fomalhaut', 'Vega', 'Canopus', 'Rigel', 'Betelgeuse',
];

// ---------------------------------------------------------------------------
// Calc specs — flat list of every valid (flags, body) combination.
// ---------------------------------------------------------------------------

class CalcSpec {
  final int flags;
  final int body;
  final bool isSidereal;
  const CalcSpec(this.flags, this.body, this.isSidereal);
}

List<CalcSpec> _buildCalcSpecs() {
  final specs = <CalcSpec>[];

  const moshierGeoFlags = [
    seFlgMosEph | seFlgSpeed,
    seFlgMosEph | seFlgSpeed | seFlgEquatorial,
    seFlgMosEph | seFlgSpeed | seFlgTruePos,
    seFlgMosEph | seFlgSpeed | seFlgNoAberr,
    seFlgMosEph | seFlgSpeed | seFlgNoGdefl,
  ];
  for (final flags in moshierGeoFlags) {
    for (final body in moshierGeocentricBodies) {
      specs.add(CalcSpec(flags, body, false));
    }
  }

  const moshierHelioFlags = [
    seFlgMosEph | seFlgSpeed | seFlgHelCtr,
    seFlgMosEph | seFlgSpeed | seFlgHelCtr | seFlgEquatorial,
  ];
  for (final flags in moshierHelioFlags) {
    for (final body in helioBodies) {
      specs.add(CalcSpec(flags, body, false));
    }
  }

  for (final body in moshierGeocentricBodies) {
    specs.add(CalcSpec(seFlgMosEph | seFlgSpeed | seFlgSidereal, body, true));
  }

  const sweGeoFlags = [
    seFlgSwiEph | seFlgSpeed,
    seFlgSwiEph | seFlgSpeed | seFlgEquatorial,
    seFlgSwiEph | seFlgSpeed | seFlgTruePos,
    seFlgSwiEph | seFlgSpeed | seFlgNoAberr,
    seFlgSwiEph | seFlgSpeed | seFlgNoGdefl,
  ];
  for (final flags in sweGeoFlags) {
    for (final body in sweGeocentricBodies) {
      specs.add(CalcSpec(flags, body, false));
    }
  }

  const sweHelioFlags = [
    seFlgSwiEph | seFlgSpeed | seFlgHelCtr,
    seFlgSwiEph | seFlgSpeed | seFlgHelCtr | seFlgEquatorial,
  ];
  for (final flags in sweHelioFlags) {
    for (final body in helioBodies) {
      specs.add(CalcSpec(flags, body, false));
    }
  }

  const sweBaryFlags = [
    seFlgSwiEph | seFlgSpeed | seFlgBaryCtr,
    seFlgSwiEph | seFlgSpeed | seFlgBaryCtr | seFlgEquatorial,
  ];
  for (final flags in sweBaryFlags) {
    for (final body in baryBodies) {
      specs.add(CalcSpec(flags, body, false));
    }
  }

  for (final body in sweGeocentricBodies) {
    specs.add(CalcSpec(seFlgSwiEph | seFlgSpeed | seFlgSidereal, body, true));
  }

  return specs;
}

/// Quarterly dates across -2000 to +3000 CE = 20,004 dates.
List<(int year, int month)> _buildDates() {
  final dates = <(int, int)>[];
  for (int year = -2000; year <= 3000; year++) {
    dates.add((year, 1));
    dates.add((year, 4));
    dates.add((year, 7));
    dates.add((year, 10));
  }
  return dates;
}

// ---------------------------------------------------------------------------
// Worker data structures
// ---------------------------------------------------------------------------

class WorkerCounts {
  int calcUt = 0;
  int calc = 0;
  int houses = 0;
  int housePos = 0;
  int gauquelin = 0;
  int ayanamsa = 0;
  int dateTime = 0;
  int positionExt = 0;
  int fixedStar = 0;
  int crossing = 0;
  int riseSet = 0;
  int eclipse = 0;
  int heliacal = 0;
  int coordinate = 0;
  int utility = 0;
  int name = 0;
  int config = 0;
  int expectedErrors = 0;

  int get total =>
      calcUt + calc + houses + housePos + gauquelin + ayanamsa +
      dateTime + positionExt + fixedStar + crossing + riseSet + eclipse +
      heliacal + coordinate + utility + name + config;
}

class WorkerConfig {
  final String libPath;
  final int isolateId;
  final int assignedAyanamsa;
  final String ephePath;
  final List<CalcSpec> specs;
  final List<(int, int)> dates;
  final bool hasStarFile;
  final SendPort resultPort;

  WorkerConfig({
    required this.libPath,
    required this.isolateId,
    required this.assignedAyanamsa,
    required this.ephePath,
    required this.specs,
    required this.dates,
    required this.hasStarFile,
    required this.resultPort,
  });
}

/// Flat structure for isolate boundary crossing via SendPort.
class WorkerResult {
  final int isolateId;
  final int assignedAyanamsa;
  final Map<String, int> counts;
  final double refLongitude;
  final double refAscendant;
  final int elapsedMs;
  final List<String> methodsCalled;
  final String? fatalError;

  WorkerResult({
    required this.isolateId,
    required this.assignedAyanamsa,
    required this.counts,
    required this.refLongitude,
    required this.refAscendant,
    required this.elapsedMs,
    required this.methodsCalled,
    this.fatalError,
  });

  int get totalCount => counts.values
      .where((v) => v > 0)
      .fold(0, (a, b) => a + b) - (counts['expectedErrors'] ?? 0);
}

Map<String, int> _countsToMap(WorkerCounts c) => {
  'calcUt': c.calcUt, 'calc': c.calc, 'houses': c.houses,
  'housePos': c.housePos, 'gauquelin': c.gauquelin, 'ayanamsa': c.ayanamsa,
  'dateTime': c.dateTime, 'positionExt': c.positionExt,
  'fixedStar': c.fixedStar, 'crossing': c.crossing, 'riseSet': c.riseSet,
  'eclipse': c.eclipse, 'heliacal': c.heliacal, 'coordinate': c.coordinate,
  'utility': c.utility, 'name': c.name, 'config': c.config,
  'expectedErrors': c.expectedErrors,
};

// ---------------------------------------------------------------------------
// The 88 public methods we expect every isolate to exercise
// ---------------------------------------------------------------------------

const Set<String> allPublicMethods = {
  // Date/time (15)
  'julday', 'revjul', 'utcToJd', 'jdToUtc', 'jdetToUtc', 'utcTimeZone',
  'dateConversion', 'dayOfWeek', 'deltat', 'deltatEx', 'timeEqu',
  'sidTime', 'sidTime0', 'lmtToLat', 'latToLmt',
  // Config (13)
  'setEphePath', 'setSidMode', 'setTopo', 'setJplFile', 'setInterpolateNut',
  'setLapseRate', 'setDeltaTUserdef', 'setTidAcc', 'getTidAcc',
  'getLibraryPath', 'getCurrentFileData', 'close', 'version',
  // Positions (8)
  'calcUt', 'calc', 'nodApsUt', 'nodAps', 'getOrbitalElements',
  'orbitMaxMinTrueDistance', 'phenoUt', 'pheno',
  // Fixed stars (3)
  'fixstar2Ut', 'fixstar2', 'fixstar2Mag',
  // Houses (7)
  'houses', 'housesEx', 'housesEx2', 'housesArmc', 'housesArmcEx2',
  'housePos', 'gauquelinSector',
  // Ayanamsa (5)
  'getAyanamsaUt', 'getAyanamsa', 'getAyanamsaExUt', 'getAyanamsaEx',
  'getAyanamsaName',
  // Eclipses (10)
  'solEclipseWhenLoc', 'solEclipseWhenGlob', 'solEclipseHow',
  'solEclipseWhere', 'lunEclipseWhen', 'lunEclipseWhenLoc',
  'lunEclipseHow', 'lunOccultWhenLoc', 'lunOccultWhenGlob', 'lunOccultWhere',
  // Crossings (8)
  'solCrossUt', 'solCross', 'moonCrossUt', 'moonCross',
  'moonCrossNodeUt', 'moonCrossNode', 'helioCrossUt', 'helioCross',
  // Rise/set (2)
  'riseTrans', 'riseTransTrueHor',
  // Heliacal (3)
  'heliacalUt', 'heliacalPhenoUt', 'visLimitMag',
  // Coordinates (5)
  'azAlt', 'azAltRev', 'cotrans', 'refrac', 'refracExtended',
  // Names (2)
  'getPlanetName', 'houseName',
  // Utilities (7)
  'degnorm', 'radNorm', 'degMidp', 'radMidp', 'difDegn', 'difDeg2n',
  'splitDeg',
};

// ---------------------------------------------------------------------------
// Workload modules — top-level for isolate use
// ---------------------------------------------------------------------------

void _scrambleState(SwissEph swe, int isolateId, Set<String> methods) {
  swe.setSidMode(stdAyanamsas[isolateId % stdAyanamsas.length]);
  final (lat, lon) = locations[isolateId % locations.length];
  swe.setTopo(lon, lat, 100.0 * (isolateId % 5));
  swe.setInterpolateNut(isolateId.isEven);
  methods.addAll(['setSidMode', 'setTopo', 'setInterpolateNut']);
}

// ---- High-volume ----

void _runCalcWorkload(
  SwissEph swe, WorkerCounts counts, Set<String> methods,
  List<CalcSpec> specs, List<(int, int)> dates,
) {
  methods.addAll(['calcUt', 'calc']);

  int dateIndex = 0;
  for (final (year, month) in dates) {
    final jdUt = swe.julday(year, month, 1, 0.0);
    final isEvery5th = dateIndex % 5 == 0;

    for (final spec in specs) {
      if (spec.isSidereal) {
        for (final aya in stdAyanamsas) {
          swe.setSidMode(aya);
          swe.calcUt(jdUt, spec.body, spec.flags);
          counts.calcUt++;
        }
        for (final ud in userDefinedAyanamsas) {
          swe.setSidMode(seSidmUser, t0: ud.t0, ayanT0: ud.ayanT0);
          swe.calcUt(jdUt, spec.body, spec.flags);
          counts.calcUt++;
        }
      } else {
        swe.calcUt(jdUt, spec.body, spec.flags);
        counts.calcUt++;
        if (isEvery5th) {
          final jdEt = jdUt + swe.deltat(jdUt);
          swe.calc(jdEt, spec.body, spec.flags);
          counts.calc++;
        }
      }
    }
    dateIndex++;
  }
}

void _runHouseWorkload(
  SwissEph swe, WorkerCounts counts, Set<String> methods,
  List<(int, int)> dates, int isolateId,
) {
  methods.addAll([
    'houses', 'housesEx', 'housesEx2', 'housesArmc', 'housesArmcEx2', 'housePos',
  ]);

  final subsetLocs = nonPolarLocations.take(3).toList();
  final subsetHsys = houseSystemList.take(5).toList();

  int yearlyIndex = 0;
  for (final (year, month) in dates) {
    if (month != 7) continue;
    final jd = swe.julday(year, month, 1, 12.0);
    final isSubset = yearlyIndex % 50 == 0;

    double lastArmc = 0;

    // Non-polar locations
    for (final (lat, lon) in nonPolarLocations) {
      for (final hsys in houseSystemList) {
        swe.houses(jd, lat, lon, hsys);
        counts.houses++;

        swe.housesEx(jd, 0, lat, lon, hsys);
        counts.houses++;

        final ex2 = swe.housesEx2(jd, 0, lat, lon, hsys);
        counts.houses++;
        lastArmc = ex2.armc;
      }
    }

    // Polar location — wrap for Placidus/Koch failures
    {
      const lat = 70.0;
      const lon = 25.0;
      for (final hsys in houseSystemList) {
        try { swe.houses(jd, lat, lon, hsys); counts.houses++; }
        on SweException { counts.expectedErrors++; }
        try { swe.housesEx(jd, 0, lat, lon, hsys); counts.houses++; }
        on SweException { counts.expectedErrors++; }
        try { swe.housesEx2(jd, 0, lat, lon, hsys); counts.houses++; }
        on SweException { counts.expectedErrors++; }
      }
    }

    // Subset: housesArmc, housesArmcEx2, housePos
    if (isSubset) {
      final sunResult = swe.calcUt(jd, seSun, seFlgMosEph | seFlgSpeed);
      final nutResult = swe.calc(
        jd + swe.deltat(jd), seEclNut, seFlgMosEph,
      );
      final eps = nutResult.longitude; // true obliquity

      for (final (lat, _) in subsetLocs) {
        for (final hsys in subsetHsys) {
          swe.housesArmc(lastArmc, lat, eps, hsys);
          counts.houses++;

          swe.housesArmcEx2(lastArmc, lat, eps, hsys);
          counts.houses++;

          final hp = swe.housePos(lastArmc, lat, eps, hsys,
              sunResult.longitude, 0.0);
          counts.housePos++;
          assert(hp >= 1.0 && hp < 13.0,
              'housePos out of range: $hp');
        }
      }
    }
    yearlyIndex++;
  }
}

void _runAyanamsaWorkload(
  SwissEph swe, WorkerCounts counts, Set<String> methods,
  List<(int, int)> dates,
) {
  methods.addAll([
    'setSidMode', 'getAyanamsaUt', 'getAyanamsa',
    'getAyanamsaExUt', 'getAyanamsaEx', 'getAyanamsaName',
  ]);

  for (final (year, month) in dates) {
    final jdUt = swe.julday(year, month, 1, 0.0);
    final jdEt = jdUt + swe.deltat(jdUt);

    for (final aya in stdAyanamsas) {
      swe.setSidMode(aya);
      swe.getAyanamsaUt(jdUt);    counts.ayanamsa++;
      swe.getAyanamsa(jdEt);      counts.ayanamsa++;
      swe.getAyanamsaExUt(jdUt, seFlgSwiEph); counts.ayanamsa++;
      swe.getAyanamsaEx(jdEt, seFlgSwiEph);   counts.ayanamsa++;
      swe.getAyanamsaName(aya);    counts.ayanamsa++;
    }

    for (final ud in userDefinedAyanamsas) {
      swe.setSidMode(seSidmUser, t0: ud.t0, ayanT0: ud.ayanT0);
      swe.getAyanamsaUt(jdUt);    counts.ayanamsa++;
      swe.getAyanamsa(jdEt);      counts.ayanamsa++;
      swe.getAyanamsaExUt(jdUt, seFlgSwiEph); counts.ayanamsa++;
      swe.getAyanamsaEx(jdEt, seFlgSwiEph);   counts.ayanamsa++;
    }
  }
}

// ---- Medium-volume ----

void _runDateTimeWorkload(
  SwissEph swe, WorkerCounts counts, Set<String> methods,
  List<(int, int)> dates,
) {
  methods.addAll([
    'julday', 'revjul', 'utcToJd', 'jdToUtc', 'jdetToUtc', 'utcTimeZone',
    'dateConversion', 'dayOfWeek', 'deltat', 'deltatEx', 'timeEqu',
    'sidTime', 'sidTime0', 'lmtToLat', 'latToLmt',
  ]);

  for (final (year, month) in dates) {
    final jd = swe.julday(year, month, 1, 12.0);
    counts.dateTime++;

    final rev = swe.revjul(jd);
    counts.dateTime++;
    assert(rev.year == year && rev.month == month,
        'revjul round-trip mismatch: $year-$month → ${rev.year}-${rev.month}');

    try { swe.utcToJd(year, month, 1, 12, 0, 0.0); counts.dateTime++; }
    on SweException { counts.dateTime++; counts.expectedErrors++; }

    swe.jdToUtc(jd);
    counts.dateTime++;

    final dt = swe.deltat(jd);
    swe.jdetToUtc(jd + dt);
    counts.dateTime++;

    swe.utcTimeZone(year, month, 1, 12, 0, 0.0, 5.5);
    counts.dateTime++;

    swe.dateConversion(year, month, 1, 12.0);
    counts.dateTime++;

    swe.dayOfWeek(jd);
    counts.dateTime++;

    swe.deltat(jd);
    counts.dateTime++;

    try { swe.deltatEx(jd, seFlgSwiEph); counts.dateTime++; }
    on SweException { counts.dateTime++; counts.expectedErrors++; }

    try { swe.timeEqu(jd); counts.dateTime++; }
    on SweException { counts.dateTime++; counts.expectedErrors++; }

    swe.sidTime(jd);
    counts.dateTime++;

    swe.sidTime0(jd, 23.44, 0.001);
    counts.dateTime++;

    try {
      final lmt = swe.lmtToLat(jd, 77.209);
      counts.dateTime++;
      swe.latToLmt(lmt, 77.209);
      counts.dateTime++;
    } on SweException {
      counts.dateTime += 2;
      counts.expectedErrors++;
    }
  }
}

void _runPositionExtWorkload(
  SwissEph swe, WorkerCounts counts, Set<String> methods,
  List<(int, int)> dates,
) {
  methods.addAll([
    'nodApsUt', 'nodAps', 'getOrbitalElements',
    'orbitMaxMinTrueDistance', 'phenoUt', 'pheno',
  ]);

  const bodies = [seMercury, seVenus, seMars, seJupiter, seSaturn, seUranus];

  for (final (year, month) in dates) {
    if (month != 7) continue;
    final jd = swe.julday(year, month, 1, 12.0);
    final jdEt = jd + swe.deltat(jd);

    for (final body in bodies) {
      try { swe.nodApsUt(jd, body, seFlgSwiEph | seFlgSpeed, seNodBitMean); counts.positionExt++; }
      on SweException { counts.positionExt++; counts.expectedErrors++; }

      try { swe.nodAps(jdEt, body, seFlgSwiEph | seFlgSpeed, seNodBitOscu); counts.positionExt++; }
      on SweException { counts.positionExt++; counts.expectedErrors++; }

      try { swe.getOrbitalElements(jdEt, body, seFlgSwiEph); counts.positionExt++; }
      on SweException { counts.positionExt++; counts.expectedErrors++; }

      try { swe.orbitMaxMinTrueDistance(jdEt, body, seFlgSwiEph); counts.positionExt++; }
      on SweException { counts.positionExt++; counts.expectedErrors++; }

      try { swe.phenoUt(jd, body, seFlgSwiEph); counts.positionExt++; }
      on SweException { counts.positionExt++; counts.expectedErrors++; }

      try { swe.pheno(jdEt, body, seFlgSwiEph); counts.positionExt++; }
      on SweException { counts.positionExt++; counts.expectedErrors++; }
    }
  }
}

void _runFixedStarWorkload(
  SwissEph swe, WorkerCounts counts, Set<String> methods,
  List<(int, int)> dates,
) {
  methods.addAll(['fixstar2Ut', 'fixstar2', 'fixstar2Mag']);

  for (final (year, month) in dates) {
    if (month != 7) continue;
    final jd = swe.julday(year, month, 1, 12.0);
    final jdEt = jd + swe.deltat(jd);

    for (final star in fixedStars) {
      try { swe.fixstar2Ut(star, jd, seFlgSwiEph | seFlgSpeed); counts.fixedStar++; }
      on SweException { counts.fixedStar++; counts.expectedErrors++; }

      try { swe.fixstar2(star, jdEt, seFlgSwiEph | seFlgSpeed); counts.fixedStar++; }
      on SweException { counts.fixedStar++; counts.expectedErrors++; }
    }
  }

  for (final star in fixedStars) {
    try { swe.fixstar2Mag(star); counts.fixedStar++; }
    on SweException { counts.fixedStar++; counts.expectedErrors++; }
  }
}

void _runCoordinateWorkload(
  SwissEph swe, WorkerCounts counts, Set<String> methods,
  List<(int, int)> dates,
) {
  methods.addAll(['azAlt', 'azAltRev', 'cotrans', 'refrac', 'refracExtended']);

  for (final (year, month) in dates) {
    final jd = swe.julday(year, month, 1, 12.0);

    CalcResult sun;
    try {
      sun = swe.calcUt(jd, seSun, seFlgSwiEph | seFlgSpeed);
    } on SweException {
      counts.expectedErrors++;
      continue;
    }

    final azResult = swe.azAlt(jd, seEcl2hor,
        geolon: 77.209, geolat: 28.614,
        bodyLon: sun.longitude, bodyLat: sun.latitude,
        bodyDist: sun.distance);
    counts.coordinate++;

    swe.azAltRev(jd, seHor2ecl,
        geolon: 77.209, geolat: 28.614,
        azimuth: azResult.azimuth, altitude: azResult.trueAltitude);
    counts.coordinate++;

    swe.cotrans(sun.longitude, sun.latitude, sun.distance, 23.44);
    counts.coordinate++;

    swe.refrac(45.0, 1013.25, 15.0, seTrueToApp);
    counts.coordinate++;

    swe.refracExtended(45.0, 0.0, 1013.25, 15.0, 0.0065, seTrueToApp);
    counts.coordinate++;
  }
}

void _runUtilityWorkload(
  SwissEph swe, WorkerCounts counts, Set<String> methods,
  List<(int, int)> dates,
) {
  methods.addAll([
    'degnorm', 'radNorm', 'degMidp', 'radMidp',
    'difDegn', 'difDeg2n', 'splitDeg',
  ]);

  const pi = 3.14159265358979323846;

  for (final (year, month) in dates) {
    final degrees = (year * 360.0 / 5000.0) + month * 30.0;
    final rads = degrees * pi / 180.0;

    final norm = swe.degnorm(degrees);
    counts.utility++;
    assert(norm >= 0.0 && norm < 360.0, 'degnorm($degrees) = $norm');

    swe.radNorm(rads);                            counts.utility++;
    swe.degMidp(degrees, degrees + 180.0);         counts.utility++;
    swe.radMidp(rads, (degrees + 180.0) * pi / 180.0); counts.utility++;
    swe.difDegn(degrees, degrees - 45.0);          counts.utility++;
    swe.difDeg2n(degrees, degrees + 200.0);        counts.utility++;
    swe.splitDeg(degrees, seSplitDegRoundSec);     counts.utility++;
    swe.splitDeg(degrees, seSplitDegZodiacal);     counts.utility++;
    swe.splitDeg(degrees, seSplitDegNakshatra);    counts.utility++;
  }
}

void _runNameWorkload(SwissEph swe, WorkerCounts counts, Set<String> methods) {
  methods.addAll(['getPlanetName', 'houseName']);

  for (int id = 0; id <= 22; id++) {
    swe.getPlanetName(id);
    counts.name++;
  }
  for (final hsys in [
    hsysPlacidus, hsysKoch, hsysPorphyry, hsysRegiomontanus, hsysCampanus,
    hsysEqual, hsysWholeSign, hsysAlcabitius, hsysTopocentric, hsysMeridian,
    hsysMorinus, hsysKrusinski, hsysVehlow, hsysGauquelin,
  ]) {
    swe.houseName(hsys);
    counts.name++;
  }
}

void _runConfigWorkload(
  SwissEph swe, WorkerCounts counts, Set<String> methods, String ephePath,
) {
  methods.addAll([
    'version', 'getLibraryPath', 'getCurrentFileData', 'setEphePath',
    'setInterpolateNut', 'setLapseRate', 'setDeltaTUserdef',
    'setTidAcc', 'getTidAcc', 'setJplFile',
  ]);

  swe.version();              counts.config++;
  swe.getLibraryPath();       counts.config++;
  swe.getCurrentFileData(0);  counts.config++;
  swe.getCurrentFileData(1);  counts.config++;
  swe.getCurrentFileData(2);  counts.config++;
  swe.setEphePath(ephePath);  counts.config++;
  swe.setInterpolateNut(true);  counts.config++;
  swe.setInterpolateNut(false); counts.config++;
  swe.setLapseRate(0.0065);  counts.config++;
  swe.setLapseRate(0.0);     counts.config++;
  swe.setDeltaTUserdef(-1e-10); counts.config++;
  swe.setTidAcc(25.82);      counts.config++;
  swe.getTidAcc();            counts.config++;
  swe.setTidAcc(0.0);        counts.config++;
  swe.setJplFile('');         counts.config++;
}

// ---- Slow iterative ----

void _runCrossingWorkload(
  SwissEph swe, WorkerCounts counts, Set<String> methods,
  List<(int, int)> dates,
) {
  methods.addAll([
    'solCrossUt', 'solCross', 'moonCrossUt', 'moonCross',
    'moonCrossNodeUt', 'moonCrossNode', 'helioCrossUt', 'helioCross',
  ]);

  for (int i = 0; i < dates.length; i += 200) {
    final (year, month) = dates[i];
    final jd = swe.julday(year, month, 1, 12.0);
    final jdEt = jd + swe.deltat(jd);

    for (final lon in [0.0, 90.0, 180.0, 270.0]) {
      try { swe.solCrossUt(lon, jd, seFlgSwiEph); counts.crossing++; }
      on SweException { counts.expectedErrors++; }
      try { swe.solCross(lon, jdEt, seFlgSwiEph); counts.crossing++; }
      on SweException { counts.expectedErrors++; }
    }

    try { swe.moonCrossUt(0.0, jd, seFlgSwiEph); counts.crossing++; }
    on SweException { counts.expectedErrors++; }
    try { swe.moonCross(0.0, jdEt, seFlgSwiEph); counts.crossing++; }
    on SweException { counts.expectedErrors++; }
    try { swe.moonCrossNodeUt(jd, seFlgSwiEph); counts.crossing++; }
    on SweException { counts.expectedErrors++; }
    try { swe.moonCrossNode(jdEt, seFlgSwiEph); counts.crossing++; }
    on SweException { counts.expectedErrors++; }

    if (i % 1000 == 0) {
      try { swe.helioCrossUt(seMars, 0.0, jd, seFlgSwiEph, 1); counts.crossing++; }
      on SweException { counts.expectedErrors++; }
      try { swe.helioCross(seMars, 0.0, jdEt, seFlgSwiEph, 1); counts.crossing++; }
      on SweException { counts.expectedErrors++; }
    }
  }
}

void _runRiseSetWorkload(
  SwissEph swe, WorkerCounts counts, Set<String> methods,
  List<(int, int)> dates,
) {
  methods.addAll(['riseTrans', 'riseTransTrueHor']);

  int trueHorCount = 0;

  for (int i = 0; i < dates.length; i += 100) {
    final (year, month) = dates[i];
    final jd = swe.julday(year, month, 1, 12.0);

    // Non-polar
    for (final (lat, lon) in nonPolarLocations) {
      for (final body in [seSun, seMoon]) {
        for (final rsmi in [seCalcRise, seCalcSet]) {
          try {
            swe.riseTrans(jd, body,
                epheflag: seFlgSwiEph, rsmi: rsmi,
                geolon: lon, geolat: lat);
            counts.riseSet++;
          } on SweException { counts.expectedErrors++; }
        }
      }
    }

    // Polar — circumpolar expected
    for (final rsmi in [seCalcRise, seCalcSet]) {
      try {
        final r = swe.riseTrans(jd, seSun,
            epheflag: seFlgSwiEph, rsmi: rsmi,
            geolon: 25.0, geolat: 70.0);
        counts.riseSet++;
        if (r.returnFlag == -2) counts.expectedErrors++;
      } on SweException { counts.expectedErrors++; }
    }

    // riseTransTrueHor — first 20 sampled dates
    if (trueHorCount < 20) {
      for (final (lat, lon) in nonPolarLocations.take(3)) {
        try {
          swe.riseTransTrueHor(jd, seSun,
              epheflag: seFlgSwiEph, rsmi: seCalcRise,
              geolon: lon, geolat: lat, horizonHeight: 0.5);
          counts.riseSet++;
        } on SweException { counts.expectedErrors++; }
      }
      trueHorCount++;
    }
  }
}

void _runEclipseWorkload(
  SwissEph swe, WorkerCounts counts, Set<String> methods,
) {
  methods.addAll([
    'solEclipseWhenGlob', 'solEclipseHow', 'solEclipseWhere', 'solEclipseWhenLoc',
    'lunEclipseWhen', 'lunEclipseHow', 'lunEclipseWhenLoc',
    'lunOccultWhenGlob', 'lunOccultWhenLoc', 'lunOccultWhere',
  ]);

  // Solar eclipses — chain 10
  var jdSearch = 2451545.0;
  for (int i = 0; i < 10; i++) {
    try {
      final glob = swe.solEclipseWhenGlob(jdSearch, seFlgSwiEph);
      counts.eclipse++;
      final jdMax = glob.maxEclipse;

      try { swe.solEclipseHow(jdMax, seFlgSwiEph, geolon: 77.209, geolat: 28.614); counts.eclipse++; }
      catch (_) { counts.expectedErrors++; }
      try { swe.solEclipseWhere(jdMax, seFlgSwiEph); counts.eclipse++; }
      catch (_) { counts.expectedErrors++; }
      try { swe.solEclipseWhenLoc(jdSearch, seFlgSwiEph, geolon: 77.209, geolat: 28.614); counts.eclipse++; }
      catch (_) { counts.expectedErrors++; }

      jdSearch = jdMax + 30;
    } catch (_) { counts.expectedErrors++; jdSearch += 180; }
  }

  // Lunar eclipses — chain 10
  jdSearch = 2451545.0;
  for (int i = 0; i < 10; i++) {
    try {
      final glob = swe.lunEclipseWhen(jdSearch, seFlgSwiEph);
      counts.eclipse++;
      final jdMax = glob.maxEclipse;

      try { swe.lunEclipseHow(jdMax, seFlgSwiEph, geolon: 77.209, geolat: 28.614); counts.eclipse++; }
      catch (_) { counts.expectedErrors++; }
      try { swe.lunEclipseWhenLoc(jdSearch, seFlgSwiEph, geolon: 77.209, geolat: 28.614); counts.eclipse++; }
      catch (_) { counts.expectedErrors++; }

      jdSearch = jdMax + 30;
    } catch (_) { counts.expectedErrors++; jdSearch += 180; }
  }

  // Lunar occultations of Mars — chain 5
  jdSearch = 2451545.0;
  for (int i = 0; i < 5; i++) {
    try {
      final glob = swe.lunOccultWhenGlob(jdSearch, seMars, seFlgSwiEph);
      counts.eclipse++;
      final jdMax = glob.maxEclipse;

      try { swe.lunOccultWhenLoc(jdSearch, seMars, seFlgSwiEph, geolon: 77.209, geolat: 28.614); counts.eclipse++; }
      catch (_) { counts.expectedErrors++; }
      try { swe.lunOccultWhere(jdMax, seMars, seFlgSwiEph); counts.eclipse++; }
      catch (_) { counts.expectedErrors++; }

      jdSearch = jdMax + 30;
    } catch (_) { counts.expectedErrors++; jdSearch += 180; }
  }
}

void _runHeliacalWorkload(
  SwissEph swe, WorkerCounts counts, Set<String> methods,
) {
  methods.addAll(['heliacalUt', 'heliacalPhenoUt', 'visLimitMag']);

  const atmo = AtmoConditions(
    pressure: 1013.25, temperature: 15.0, humidity: 40.0, extinction: 0.25,
  );
  const observer = ObserverConditions(age: 36, snellenRatio: 1.0);

  for (final year in [0, 500, 1000, 1500, 2000]) {
    final jd = 2451545.0 + (year - 2000) * 365.25;
    for (final planet in ['Venus', 'Mars', 'Jupiter']) {
      try {
        swe.heliacalUt(jd,
            geolon: 77.209, geolat: 28.614, atmo: atmo, observer: observer,
            objectName: planet, typeEvent: seHeliacalRising, flags: seFlgSwiEph);
        counts.heliacal++;
      } on SweException { counts.expectedErrors++; }

      try {
        swe.heliacalPhenoUt(jd,
            geolon: 77.209, geolat: 28.614, atmo: atmo, observer: observer,
            objectName: planet, typeEvent: seHeliacalRising, flags: seFlgSwiEph);
        counts.heliacal++;
      } on SweException { counts.expectedErrors++; }

      try {
        swe.visLimitMag(jd,
            geolon: 77.209, geolat: 28.614, atmo: atmo, observer: observer,
            objectName: planet, flags: seFlgSwiEph);
        counts.heliacal++;
      } on SweException { counts.expectedErrors++; }
    }
  }
}

void _runGauquelinWorkload(
  SwissEph swe, WorkerCounts counts, Set<String> methods,
  List<(int, int)> dates,
) {
  methods.add('gauquelinSector');

  const locs = [(28.6139, 77.2090), (51.5074, -0.1278), (40.7128, -74.0060)];
  const bodies = [seSun, seMoon, seMars];

  for (int i = 0; i < dates.length; i += 400) {
    final (year, month) = dates[i];
    final jd = swe.julday(year, month, 1, 12.0);

    for (final (lat, lon) in locs) {
      for (final body in bodies) {
        try { swe.gauquelinSector(jd, body, seFlgSwiEph, 0, geolon: lon, geolat: lat); counts.gauquelin++; }
        on SweException { counts.expectedErrors++; }
        try { swe.gauquelinSector(jd, body, seFlgSwiEph, 1, geolon: lon, geolat: lat); counts.gauquelin++; }
        on SweException { counts.expectedErrors++; }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Isolate worker
// ---------------------------------------------------------------------------

void _isolateWorker(WorkerConfig config) {
  final sw = Stopwatch()..start();
  final counts = WorkerCounts();
  final methods = <String>{};

  try {
    final swe = SwissEph(config.libPath);
    swe.setEphePath(config.ephePath);

    // Phase 0: Reference values for isolation verification
    swe.setSidMode(config.assignedAyanamsa);
    final jd2000 = swe.julday(2000, 1, 1, 0.0);
    final ref = swe.calcUt(
      jd2000, seSun, seFlgMosEph | seFlgSpeed | seFlgSidereal,
    );
    counts.calcUt++;
    final refLon = ref.longitude;

    // Second reference: housesEx2 Ascendant at Delhi with assigned ayanamsa
    swe.setSidMode(config.assignedAyanamsa);
    final hRef = swe.housesEx2(jd2000, seFlgSidereal, 28.6139, 77.209, hsysCampanus);
    counts.houses++;
    final refAsc = hRef.cusps[1]; // Ascendant

    // Phase 1: High-volume
    _scrambleState(swe, config.isolateId, methods);
    _runCalcWorkload(swe, counts, methods, config.specs, config.dates);

    _scrambleState(swe, config.isolateId, methods);
    _runHouseWorkload(swe, counts, methods, config.dates, config.isolateId);

    _scrambleState(swe, config.isolateId, methods);
    _runAyanamsaWorkload(swe, counts, methods, config.dates);

    // Phase 2: Medium-volume
    _scrambleState(swe, config.isolateId, methods);
    _runDateTimeWorkload(swe, counts, methods, config.dates);

    _scrambleState(swe, config.isolateId, methods);
    _runPositionExtWorkload(swe, counts, methods, config.dates);

    _scrambleState(swe, config.isolateId, methods);
    _runFixedStarWorkload(swe, counts, methods, config.dates);

    _scrambleState(swe, config.isolateId, methods);
    _runCoordinateWorkload(swe, counts, methods, config.dates);

    _scrambleState(swe, config.isolateId, methods);
    _runUtilityWorkload(swe, counts, methods, config.dates);

    _runNameWorkload(swe, counts, methods);
    _runConfigWorkload(swe, counts, methods, config.ephePath);

    // Phase 3: Slow iterative
    _scrambleState(swe, config.isolateId, methods);
    _runCrossingWorkload(swe, counts, methods, config.dates);

    _scrambleState(swe, config.isolateId, methods);
    _runRiseSetWorkload(swe, counts, methods, config.dates);

    _scrambleState(swe, config.isolateId, methods);
    _runEclipseWorkload(swe, counts, methods);

    _scrambleState(swe, config.isolateId, methods);
    _runHeliacalWorkload(swe, counts, methods);

    _scrambleState(swe, config.isolateId, methods);
    _runGauquelinWorkload(swe, counts, methods, config.dates);

    // close() is itself a method to exercise
    methods.add('close');
    swe.close();
    counts.config++;

    sw.stop();
    config.resultPort.send(WorkerResult(
      isolateId: config.isolateId,
      assignedAyanamsa: config.assignedAyanamsa,
      counts: _countsToMap(counts),
      refLongitude: refLon,
      refAscendant: refAsc,
      elapsedMs: sw.elapsedMilliseconds,
      methodsCalled: methods.toList(),
    ));
  } catch (e, st) {
    sw.stop();
    config.resultPort.send(WorkerResult(
      isolateId: config.isolateId,
      assignedAyanamsa: config.assignedAyanamsa,
      counts: _countsToMap(counts),
      refLongitude: -1,
      refAscendant: -1,
      elapsedMs: sw.elapsedMilliseconds,
      methodsCalled: methods.toList(),
      fatalError: '$e\n$st',
    ));
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _findLibrary() {
  final candidates = Directory('.dart_tool')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) =>
          f.path.endsWith('libswisseph.so') ||
          f.path.endsWith('libswisseph.dylib'))
      .map((f) => f.path)
      .toList();
  if (candidates.isEmpty) {
    throw StateError('libswisseph not found in .dart_tool/');
  }
  return candidates.first;
}

String _copyLibForIsolate(String sourcePath, int id) {
  final tmpDir = Directory.systemTemp.createTempSync('swisseph_stress02_');
  final ext = sourcePath.endsWith('.dylib') ? 'dylib' : 'so';
  final destPath = '${tmpDir.path}/libswisseph_$id.$ext';
  File(sourcePath).copySync(destPath);
  return destPath;
}

String _formatCount(int n) {
  if (n >= 1e9) return '${(n / 1e9).toStringAsFixed(2)}B';
  if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}M';
  if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(1)}K';
  return n.toString();
}

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------

void main() {
  late String baseLibPath;
  late String ephePath;
  late bool hasStarFile;
  final specs = _buildCalcSpecs();
  final dates = _buildDates();

  // Tally expected volume
  final nonSidereal = specs.where((s) => !s.isSidereal).length;
  final siderealBodies = specs.where((s) => s.isSidereal).length;
  final calcsPerDate = nonSidereal + (siderealBodies * (stdAyanamsas.length + userDefinedAyanamsas.length));
  final houseDatesPerIsolate = dates.length ~/ 4;
  final housesPerIsolate =
      houseDatesPerIsolate * nonPolarLocations.length * houseSystemList.length * 3;
  final planetaryPerIsolate = dates.length * calcsPerDate + 1;
  final totalPerIsolate = planetaryPerIsolate + housesPerIsolate;

  stderr.writeln('=== STRESS TEST 0.2 CONFIG ===');
  stderr.writeln('Full API coverage: ${allPublicMethods.length} methods');
  stderr.writeln('Ephemerides: Moshier + Swiss Ephemeris (.se1 files)');
  stderr.writeln('Dates: ${dates.length} (quarterly, -2000 to +3000 CE)');
  stderr.writeln('Calc specs: ${specs.length} '
      '($nonSidereal non-sidereal + $siderealBodies sidereal × '
      '${stdAyanamsas.length}+${userDefinedAyanamsas.length} ayanamsas)');
  stderr.writeln('Calcs per date: $calcsPerDate');
  stderr.writeln('Per isolate: ~${_formatCount(planetaryPerIsolate)} planetary '
      '+ ${_formatCount(housesPerIsolate)} houses '
      '= ~${_formatCount(totalPerIsolate)} (calc+house only)');
  stderr.writeln('100 isolates: ~${_formatCount(totalPerIsolate * 100)} '
      '(calc+house; total with all modules will be higher)');
  stderr.writeln('==============================\n');

  setUpAll(() {
    baseLibPath = _findLibrary();
    ephePath = Directory('ephe').absolute.path;
    if (!Directory(ephePath).existsSync()) {
      throw StateError('ephe/ directory not found');
    }
    hasStarFile = File('$ephePath/sefstars.txt').existsSync() ||
        File('$ephePath/fixstars.cat').existsSync();
    if (!hasStarFile) {
      stderr.writeln('WARNING: sefstars.txt not found — fixstar workload will count errors');
    }
  });

  group('stress test 0.2', () {
    test('100 isolates, full API sweep, Moshier + SwissEph', () async {
      const totalTasks = 100;
      const poolSize = 20;

      final taskConfigs = List.generate(totalTasks, (i) => (
        isolateId: i,
        assignedAyanamsa: stdAyanamsas[i % stdAyanamsas.length],
      ));

      final libPaths = List.generate(
        poolSize,
        (i) => _copyLibForIsolate(baseLibPath, i),
      );

      final results = <WorkerResult>[];
      final overallSw = Stopwatch()..start();

      try {
        for (int batch = 0; batch < totalTasks; batch += poolSize) {
          final batchEnd = (batch + poolSize).clamp(0, totalTasks);
          final futures = <Future<WorkerResult>>[];

          for (int i = batch; i < batchEnd; i++) {
            final task = taskConfigs[i];
            final libPath = libPaths[i % poolSize];
            final receivePort = ReceivePort();

            futures.add(() async {
              await Isolate.spawn(
                _isolateWorker,
                WorkerConfig(
                  libPath: libPath,
                  isolateId: task.isolateId,
                  assignedAyanamsa: task.assignedAyanamsa,
                  ephePath: ephePath,
                  specs: specs,
                  dates: dates,
                  hasStarFile: hasStarFile,
                  resultPort: receivePort.sendPort,
                ),
              );
              return await receivePort.first as WorkerResult;
            }());
          }

          final batchResults = await Future.wait(futures);
          results.addAll(batchResults);

          final done = results.length;
          final totalCalcs = results.fold<int>(0, (s, r) => s + r.totalCount);
          final elapsed = overallSw.elapsed;
          final rate = elapsed.inSeconds > 0
              ? _formatCount((totalCalcs / elapsed.inSeconds).toInt())
              : '---';

          // Per-category breakdown
          final cU = results.fold<int>(0, (s, r) => s + (r.counts['calcUt'] ?? 0));
          final cH = results.fold<int>(0, (s, r) => s + (r.counts['houses'] ?? 0));
          final cA = results.fold<int>(0, (s, r) => s + (r.counts['ayanamsa'] ?? 0));
          final cE = results.fold<int>(0, (s, r) => s + (r.counts['expectedErrors'] ?? 0));

          stderr.writeln(
            '  [$done/$totalTasks] '
            '${_formatCount(totalCalcs)} calcs, '
            '${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s, '
            '$rate/sec  '
            '(calcUt: ${_formatCount(cU)}, houses: ${_formatCount(cH)}, '
            'aya: ${_formatCount(cA)}, errors: $cE)',
          );
        }

        overallSw.stop();

        // --- Verification ---

        // 1. No fatal errors
        final errors = results.where((r) => r.fatalError != null).toList();
        if (errors.isNotEmpty) {
          stderr.writeln('\nFATAL ERRORS (first 3):');
          for (final e in errors.take(3)) {
            stderr.writeln('  isolate ${e.isolateId}: ${e.fatalError}');
          }
        }
        expect(errors, isEmpty, reason: 'All isolates should complete without fatal error');

        // 2. Isolation: same ayanamsa → identical reference longitude
        final byAyanamsa = <int, List<double>>{};
        for (final r in results) {
          byAyanamsa.putIfAbsent(r.assignedAyanamsa, () => []).add(r.refLongitude);
        }
        for (final entry in byAyanamsa.entries) {
          final first = entry.value.first;
          for (final lon in entry.value) {
            expect((lon - first).abs(), lessThan(1e-8),
                reason: 'Ayanamsa ${entry.key}: reference longitude mismatch '
                    '(${entry.value.map((l) => l.toStringAsFixed(10)).toSet()})');
          }
        }

        // 3. Isolation: same ayanamsa → identical reference Ascendant
        final byAyanamsaAsc = <int, List<double>>{};
        for (final r in results) {
          byAyanamsaAsc.putIfAbsent(r.assignedAyanamsa, () => []).add(r.refAscendant);
        }
        for (final entry in byAyanamsaAsc.entries) {
          final first = entry.value.first;
          for (final asc in entry.value) {
            expect((asc - first).abs(), lessThan(1e-8),
                reason: 'Ayanamsa ${entry.key}: reference Ascendant mismatch');
          }
        }

        // 4. Different ayanamsas → different reference longitudes
        final uniqueLons = byAyanamsa.values.map((v) => v.first).toSet();
        expect(uniqueLons.length, equals(byAyanamsa.length),
            reason: 'Each ayanamsa should produce a distinct reference value');

        // 5. API coverage: all methods exercised in every isolate
        for (final r in results) {
          final called = r.methodsCalled.toSet();
          final missing = allPublicMethods.difference(called);
          expect(missing, isEmpty,
              reason: 'Isolate ${r.isolateId} missing methods: $missing');
        }

        // 6. Expected errors exercised
        final totalExpectedErrors = results.fold<int>(
          0, (s, r) => s + (r.counts['expectedErrors'] ?? 0),
        );
        expect(totalExpectedErrors, greaterThan(0),
            reason: 'Expected error paths (polar houses, circumpolar, etc.) '
                'should have been exercised');

        // Stats
        final totalCalcs = results.fold<int>(0, (s, r) => s + r.totalCount);
        final elapsed = overallSw.elapsed;
        final calcsPerSec = elapsed.inSeconds > 0
            ? totalCalcs / elapsed.inSeconds : 0;

        // Per-category totals
        final catTotals = <String, int>{};
        for (final r in results) {
          for (final entry in r.counts.entries) {
            catTotals[entry.key] = (catTotals[entry.key] ?? 0) + entry.value;
          }
        }

        stderr.writeln('\n=== STRESS TEST 0.2 RESULTS ===');
        stderr.writeln('Isolates: $totalTasks (pool of $poolSize)');
        stderr.writeln('Ephemerides: Moshier + Swiss Ephemeris');
        stderr.writeln('Total calcs: ${_formatCount(totalCalcs)}');
        stderr.writeln('Wall time: ${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s');
        stderr.writeln('Throughput: ${_formatCount(calcsPerSec.toInt())} calcs/sec');
        stderr.writeln('');
        stderr.writeln('Per-category totals:');
        for (final cat in [
          'calcUt', 'calc', 'houses', 'housePos', 'ayanamsa', 'dateTime',
          'positionExt', 'fixedStar', 'coordinate', 'utility', 'crossing',
          'riseSet', 'eclipse', 'heliacal', 'gauquelin', 'name', 'config',
        ]) {
          final v = catTotals[cat] ?? 0;
          if (v > 0) stderr.writeln('  $cat: ${_formatCount(v)}');
        }
        stderr.writeln('  expectedErrors: ${catTotals['expectedErrors'] ?? 0}');
        stderr.writeln('');
        stderr.writeln('Methods verified: ${allPublicMethods.length}/${allPublicMethods.length}');
        stderr.writeln('Ayanamsas verified: ${byAyanamsa.length} standard + '
            '${userDefinedAyanamsas.length} user-defined');
        stderr.writeln('Isolation: PASS (longitude + Ascendant)');
        stderr.writeln('API coverage: PASS');
        stderr.writeln('================================\n');
      } finally {
        for (final path in libPaths) {
          try {
            final file = File(path);
            file.deleteSync();
            file.parent.deleteSync();
          } catch (_) {}
        }
      }
    });
  });
}
