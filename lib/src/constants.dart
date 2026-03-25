/// Swiss Ephemeris constants translated from swephexp.h and sweodef.h.

// --- Ephemeris selection ---

/// Swiss Ephemeris data files (highest precision)
const int seFlgSwiEph = 2;

/// Moshier analytical ephemeris (no files needed, ~1" accuracy)
const int seFlgMosEph = 4;

/// JPL ephemeris files
const int seFlgJplEph = 1;

// --- Calculation flags ---

/// Include speed in output
const int seFlgSpeed = 256;

/// Heliocentric positions
const int seFlgHelCtr = 8;

/// True position (no aberration/deflection)
const int seFlgTruePos = 16;

/// Equatorial coordinates (RA/dec instead of lon/lat)
const int seFlgEquatorial = 2048;

/// Topocentric (requires swe_set_topo)
const int seFlgTopoCtr = 32768;

/// Sidereal zodiac (requires swe_set_sid_mode)
const int seFlgSidereal = 65536;

/// No aberration correction
const int seFlgNoAberr = 1024;

/// No gravitational deflection
const int seFlgNoGdefl = 512;

/// Cartesian (XYZ) instead of polar
const int seFlgXyz = 4096;

/// Radians instead of degrees
const int seFlgRadians = 8192;

/// Barycentric
const int seFlgBaryCtr = 16384;

/// ICRS reference frame
const int seFlgIcrs = 131072;

// --- Body IDs ---

const int seSun = 0;
const int seMoon = 1;
const int seMercury = 2;
const int seVenus = 3;
const int seMars = 4;
const int seJupiter = 5;
const int seSaturn = 6;
const int seUranus = 7;
const int seNeptune = 8;
const int sePluto = 9;
const int seMeanNode = 10;
const int seTrueNode = 11;
const int seMeanApog = 12;
const int seOscuApog = 13;
const int seEarth = 14;
const int seChiron = 15;
const int sePholus = 16;
const int seCeres = 17;
const int sePallas = 18;
const int seJuno = 19;
const int seVesta = 20;
const int seIntpApog = 21;
const int seIntpPerg = 22;

/// Offset for numbered asteroids: body = seAstOffset + asteroid_number
const int seAstOffset = 10000;

/// Hamburger School (Uranian) fictitious bodies
const int seCupido = 40;
const int seHades = 41;
const int seZeus = 42;
const int seKronos = 43;
const int seApollon = 44;
const int seAdmetos = 45;
const int seVulkanus = 46;
const int sePoseidon = 47;

// --- Calendar type ---

const int seGregCal = 1;
const int seJulCal = 0;

// --- House system codes (ASCII values) ---

/// Placidus
const int hsysPlacidus = 0x50; // 'P'

/// Koch
const int hsysKoch = 0x4B; // 'K'

/// Porphyry
const int hsysPorphyry = 0x4F; // 'O'

/// Regiomontanus
const int hsysRegiomontanus = 0x52; // 'R'

/// Campanus
const int hsysCampanus = 0x43; // 'C'

/// Equal (cusp 1 = Asc)
const int hsysEqual = 0x45; // 'E'

/// Whole Sign
const int hsysWholeSign = 0x57; // 'W'

/// Alcabitius
const int hsysAlcabitius = 0x42; // 'B'

/// Topocentric (Polich-Page)
const int hsysTopocentric = 0x54; // 'T'

/// Meridian (Axial)
const int hsysMeridian = 0x58; // 'X'

/// Morinus
const int hsysMorinus = 0x4D; // 'M'

/// Krusinski-Pisa
const int hsysKrusinski = 0x55; // 'U'

/// Vehlow equal
const int hsysVehlow = 0x56; // 'V'

/// Gauquelin sectors (36 sectors)
const int hsysGauquelin = 0x47; // 'G'

// --- Ayanamsa modes ---

const int seSidmFaganBradley = 0;
const int seSidmLahiri = 1;
const int seSidmDeluce = 2;
const int seSidmRaman = 3;
const int seSidmUshashashi = 4;
const int seSidmKrishnamurti = 5;
const int seSidmDjwhalKhul = 6;
const int seSidmYukteshwar = 7;
const int seSidmJnBhasin = 8;
const int seSidmBabylKugler1 = 9;
const int seSidmBabylKugler2 = 10;
const int seSidmBabylKugler3 = 11;
const int seSidmBabylHuber = 12;
const int seSidmBabylEtpsc = 13;
const int seSidmAldebaran15tau = 14;
const int seSidmHipparchos = 15;
const int seSidmSassanian = 16;
const int seSidmGalcent0sag = 17;
const int seSidmJ2000 = 18;
const int seSidmJ1900 = 19;
const int seSidmB1950 = 20;
const int seSidmSuryasiddhanta = 21;
const int seSidmSuryasiddhantaMsun = 22;
const int seSidmAryabhata = 23;
const int seSidmAryabhataMsun = 24;
const int seSidmSsRevati = 25;
const int seSidmSsCitra = 26;
const int seSidmTrueCitra = 27;
const int seSidmTrueRevati = 28;
const int seSidmTruePushya = 29;
const int seSidmGalcentRgilbrand = 30;
const int seSidmGalequIau1958 = 31;
const int seSidmGalequTrue = 32;
const int seSidmGalequMula = 33;
const int seSidmGalalignMardyks = 34;
const int seSidmTrueMula = 35;
const int seSidmGalcentMulaWilhelm = 36;
const int seSidmAryabhata522 = 37;
const int seSidmBabylBritton = 38;
const int seSidmTrueSheoran = 39;
const int seSidmGalcentCochrane = 40;
const int seSidmGalequFiorenza = 41;
const int seSidmValensMoon = 42;
const int seSidmLahiri1940 = 43;
const int seSidmLahiriVp285 = 44;
const int seSidmKrishnamurtiVp291 = 45;
const int seSidmLahiriIcrc = 46;

/// User-defined ayanamsa
const int seSidmUser = 255;

// --- Rise/set flags ---

const int seCalcRise = 1;
const int seCalcSet = 2;
const int seCalcMTransit = 4;
const int seCalcITransit = 8;
const int seBitDiscCenter = 256;
const int seBitDiscBottom = 8192;
const int seBitNoRefraction = 512;
const int seBitHinduRising = 896; // disc center + no refraction + geocentric no ecl lat
const int seBitGeoCtrNoEclLat = 128;
const int seBitCivilTwilight = 1024;
const int seBitNauticTwilight = 2048;
const int seBitAstroTwilight = 4096;
const int seBitFixedDiscSize = 16384;

// --- Node/apsides method flags ---

/// Mean nodes/apsides
const int seNodBitMean = 1;

/// Osculating nodes/apsides
const int seNodBitOscu = 2;

/// Osculating, motion about solar system barycenter
const int seNodBitOscuBar = 4;

/// Focal point of orbit instead of aphelion
const int seNodBitFoPoint = 256;

// --- Heliacal event types ---

/// Heliacal rising (= morning first)
const int seHeliacalRising = 1;

/// Heliacal setting (= evening last)
const int seHeliacalSetting = 2;

/// Morning first (= heliacal rising)
const int seMorningFirst = 1;

/// Evening last (= heliacal setting)
const int seEveningLast = 2;

/// Evening first
const int seEveningFirst = 3;

/// Morning last
const int seMorningLast = 4;

// --- Heliacal flags ---

const int seHelFlagLongSearch = 128;
const int seHelFlagHighPrecision = 256;
const int seHelFlagOpticalParams = 512;
const int seHelFlagNoDetails = 1024;

// --- Sidereal mode bits ---

/// Project onto ecliptic of t0
const int seSidBitEclT0 = 256;

/// Project onto solar system plane
const int seSidBitSsyPlane = 512;

/// User-defined UT
const int seSidBitUserUt = 1024;

/// Project onto ecliptic of date
const int seSidBitEclDate = 2048;

/// No precession offset
const int seSidBitNoPrecOffset = 4096;

/// Original precession
const int seSidBitPrecOrig = 8192;

// --- Special body IDs ---

/// Ecliptic/nutation (special body for swe_calc)
const int seEclNut = -1;

// --- Additional calc flags ---

/// J2000 equator/ecliptic
const int seFlgJ2000 = 32;

/// No nutation
const int seFlgNoNut = 64;

/// Speed from 3-body formula (less precise)
const int seFlgSpeed3 = 128;

/// JPL Horizons mode
const int seFlgJplHor = 262144;

/// JPL Horizons approximation mode
const int seFlgJplHorApprox = 524288;

/// Center body (for swe_calc)
const int seFlgCenterBody = 1048576;

// --- Azimuth/altitude conversion flags ---
// Note: The direction (e.g. ecl→hor vs hor→ecl) is determined by which
// function you call (azAlt vs azAltRev), not by the flag value.
// These flags select the coordinate system (ecliptic=0, equatorial=1).

/// Ecliptic coordinates (for azAlt: ecliptic→horizon; for azAltRev: horizon→ecliptic)
const int seEcl2hor = 0;
/// Equatorial coordinates (for azAlt: equatorial→horizon; for azAltRev: horizon→equatorial)
const int seEqu2hor = 1;
/// Alias for seEcl2hor (same value; direction is determined by the function called)
const int seHor2ecl = 0;
/// Alias for seEqu2hor (same value; direction is determined by the function called)
const int seHor2equ = 1;

// --- Refraction flags ---

/// True altitude to apparent altitude
const int seTrueToApp = 0;
/// Apparent altitude to true altitude
const int seAppToTrue = 1;

// --- Split degree flags ---

const int seSplitDegRoundSec = 1;
const int seSplitDegRoundMin = 2;
const int seSplitDegRoundDeg = 4;
const int seSplitDegZodiacal = 8;
const int seSplitDegKeepSign = 16;
const int seSplitDegKeepDeg = 32;
const int seSplitDegNakshatra = 1024;

// --- Eclipse type flags ---

const int seEclCentral = 1;
const int seEclNonCentral = 2;
const int seEclTotal = 4;
const int seEclAnnular = 8;
const int seEclPartial = 16;
const int seEclHybrid = 32; // annular-total
const int seEclPenumbral = 64;
const int seEclVisible = 128;
const int seEclMaxVisible = 256;
const int seEclPartBegVisible = 512;
const int seEclTotBegVisible = 1024;
const int seEclTotEndVisible = 2048;
const int seEclPartEndVisible = 4096;
const int seEclPenumbBegVisible = 8192;
const int seEclPenumbEndVisible = 16384;
const int seEclOneTry = 32768;
