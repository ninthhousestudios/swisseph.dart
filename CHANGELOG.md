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
