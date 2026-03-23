## 0.1.2

- Fix Android/NDK linking: link `libm` explicitly via `libraries: ['m']`
  in the build hook. Desktop glibc links libm implicitly; Android's Bionic
  does not, causing `dlopen` failures for math symbols (`sin`, `cos`,
  `sincos`, etc.).
- Document ephemeris file discovery for package consumers: use
  `Isolate.resolvePackageUri` to locate the bundled `ephe/` directory
  at runtime.

## 0.1.1

- Bundle Swiss Ephemeris data files in `ephe/` — sub-arcsecond precision
  out of the box with no extra downloads.
- Included: planets, Moon, main asteroids (Ceres, Pallas, Juno, Vesta,
  Chiron, Pholus), fixed stars, and Hygiea.
- Coverage: ~5400 BC – 5400 AD (~10,800 years).

## 0.1.0

- Initial release.
- 15 methods: `calcUt`, `houses`, `julday`, `revjul`, `riseTrans`,
  `getAyanamsaUt`, `getAyanamsaExUt`, `getAyanamsaName`, `setSidMode`,
  `setEphePath`, `setTopo`, `getPlanetName`, `houseName`, `degnorm`,
  `close`, `version`.
- All 47 standard ayanamsa modes.
- 11 house systems.
- Moshier, Swiss Ephemeris, and JPL ephemeris support.
- Tropical, sidereal, heliocentric, barycentric, and equatorial
  coordinates.
- Native asset build hook — C source compiles automatically on
  `dart pub get`.
- Isolate-safe via unique `.so` copies per isolate.
- 26 unit tests + 545-value cross-validation against pyswisseph.
