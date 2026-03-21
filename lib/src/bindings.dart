import 'dart:ffi' as ffi;

/// Raw dart:ffi bindings to Swiss Ephemeris C functions.
///
/// Each function is looked up lazily from the DynamicLibrary.
/// This class is private to the package — use [SwissEph] instead.
class SweBindings {
  final ffi.DynamicLibrary _lib;

  SweBindings(this._lib);

  // --- Date/time ---

  late final swe_julday = _lib
      .lookupFunction<
          ffi.Double Function(
              ffi.Int32, ffi.Int32, ffi.Int32, ffi.Double, ffi.Int32),
          double Function(int, int, int, double, int)>('swe_julday');

  late final swe_revjul = _lib.lookupFunction<
      ffi.Void Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Double>),
      void Function(double, int, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Double>)>('swe_revjul');

  // --- Configuration ---

  late final swe_set_ephe_path = _lib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Char>),
      void Function(ffi.Pointer<ffi.Char>)>('swe_set_ephe_path');

  late final swe_set_sid_mode = _lib.lookupFunction<
      ffi.Void Function(ffi.Int32, ffi.Double, ffi.Double),
      void Function(int, double, double)>('swe_set_sid_mode');

  late final swe_set_topo = _lib.lookupFunction<
      ffi.Void Function(ffi.Double, ffi.Double, ffi.Double),
      void Function(double, double, double)>('swe_set_topo');

  late final swe_close = _lib
      .lookupFunction<ffi.Void Function(), void Function()>('swe_close');

  late final swe_version = _lib.lookupFunction<
      ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>),
      ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)>('swe_version');

  // --- Calculations ---

  late final swe_calc_ut = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Char>),
      int Function(double, int, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Char>)>('swe_calc_ut');

  late final swe_houses = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Double, ffi.Double, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>),
      int Function(double, double, double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>)>('swe_houses');

  // --- Ayanamsa ---

  late final swe_get_ayanamsa_ut = _lib.lookupFunction<
      ffi.Double Function(ffi.Double),
      double Function(double)>('swe_get_ayanamsa_ut');

  late final swe_get_ayanamsa_ex_ut = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Char>),
      int Function(double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Char>)>('swe_get_ayanamsa_ex_ut');

  late final swe_get_ayanamsa_name = _lib.lookupFunction<
      ffi.Pointer<ffi.Char> Function(ffi.Int32),
      ffi.Pointer<ffi.Char> Function(int)>('swe_get_ayanamsa_name');

  // --- Names ---

  late final swe_get_planet_name = _lib.lookupFunction<
      ffi.Pointer<ffi.Char> Function(ffi.Int32, ffi.Pointer<ffi.Char>),
      ffi.Pointer<ffi.Char> Function(
          int, ffi.Pointer<ffi.Char>)>('swe_get_planet_name');

  late final swe_house_name = _lib.lookupFunction<
      ffi.Pointer<ffi.Char> Function(ffi.Int32),
      ffi.Pointer<ffi.Char> Function(int)>('swe_house_name');

  // --- Rise/set ---

  late final swe_rise_trans = _lib.lookupFunction<
      ffi.Int32 Function(
          ffi.Double,
          ffi.Int32,
          ffi.Pointer<ffi.Char>,
          ffi.Int32,
          ffi.Int32,
          ffi.Pointer<ffi.Double>,
          ffi.Double,
          ffi.Double,
          ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Char>),
      int Function(
          double,
          int,
          ffi.Pointer<ffi.Char>,
          int,
          int,
          ffi.Pointer<ffi.Double>,
          double,
          double,
          ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Char>)>('swe_rise_trans');

  // --- Utilities ---

  late final swe_degnorm = _lib.lookupFunction<
      ffi.Double Function(ffi.Double),
      double Function(double)>('swe_degnorm');
}
