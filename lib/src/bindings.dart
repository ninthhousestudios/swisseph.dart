import 'ffi_types.dart' as ffi;

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

  late final swe_utc_to_jd = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Int32, ffi.Int32, ffi.Int32, ffi.Int32, ffi.Int32,
          ffi.Double, ffi.Int32, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(int, int, int, int, int, double, int,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_utc_to_jd');

  late final swe_jdut1_to_utc = _lib.lookupFunction<
      ffi.Void Function(
          ffi.Double, ffi.Int32, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Double>),
      void Function(
          double, int, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Double>)>('swe_jdut1_to_utc');

  late final swe_jdet_to_utc = _lib.lookupFunction<
      ffi.Void Function(
          ffi.Double, ffi.Int32, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Double>),
      void Function(
          double, int, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Double>)>('swe_jdet_to_utc');

  late final swe_utc_time_zone = _lib.lookupFunction<
      ffi.Void Function(
          ffi.Int32, ffi.Int32, ffi.Int32, ffi.Int32, ffi.Int32, ffi.Double,
          ffi.Double, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Double>),
      void Function(
          int, int, int, int, int, double, double, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Double>)>('swe_utc_time_zone');

  late final swe_date_conversion = _lib.lookupFunction<
      ffi.Int32 Function(
          ffi.Int32, ffi.Int32, ffi.Int32, ffi.Double, ffi.Uint8,
          ffi.Pointer<ffi.Double>),
      int Function(
          int, int, int, double, int,
          ffi.Pointer<ffi.Double>)>('swe_date_conversion');

  late final swe_day_of_week = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double),
      int Function(double)>('swe_day_of_week');

  // --- Configuration ---

  late final swe_set_ephe_path = _lib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Uint8>),
      void Function(ffi.Pointer<ffi.Uint8>)>('swe_set_ephe_path');

  late final swe_set_sid_mode = _lib.lookupFunction<
      ffi.Void Function(ffi.Int32, ffi.Double, ffi.Double),
      void Function(int, double, double)>('swe_set_sid_mode');

  late final swe_set_topo = _lib.lookupFunction<
      ffi.Void Function(ffi.Double, ffi.Double, ffi.Double),
      void Function(double, double, double)>('swe_set_topo');

  late final swe_close = _lib
      .lookupFunction<ffi.Void Function(), void Function()>('swe_close');

  late final swe_version = _lib.lookupFunction<
      ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<ffi.Uint8>),
      ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<ffi.Uint8>)>('swe_version');

  late final swe_set_jpl_file = _lib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Uint8>),
      void Function(ffi.Pointer<ffi.Uint8>)>('swe_set_jpl_file');

  late final swe_get_library_path = _lib.lookupFunction<
      ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<ffi.Uint8>),
      ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<ffi.Uint8>)>('swe_get_library_path');

  late final swe_get_current_file_data = _lib.lookupFunction<
      ffi.Pointer<ffi.Uint8> Function(
          ffi.Int32, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Int32>),
      ffi.Pointer<ffi.Uint8> Function(
          int, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Int32>)>('swe_get_current_file_data');

  late final swe_set_interpolate_nut = _lib.lookupFunction<
      ffi.Void Function(ffi.Int32),
      void Function(int)>('swe_set_interpolate_nut');

  late final swe_set_lapse_rate = _lib.lookupFunction<
      ffi.Void Function(ffi.Double),
      void Function(double)>('swe_set_lapse_rate');

  // --- Calculations ---

  late final swe_calc_ut = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(double, int, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>)>('swe_calc_ut');

  late final swe_houses = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Double, ffi.Double, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>),
      int Function(double, double, double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>)>('swe_houses');

  late final swe_calc = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(double, int, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>)>('swe_calc');

  late final swe_houses_ex = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Double, ffi.Double,
          ffi.Int32, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>),
      int Function(double, int, double, double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>)>('swe_houses_ex');

  late final swe_houses_ex2 = _lib.lookupFunction<
      ffi.Int32 Function(
          ffi.Double, ffi.Int32, ffi.Double, ffi.Double, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>),
      int Function(
          double, int, double, double, int,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>)>('swe_houses_ex2');

  late final swe_houses_armc = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Double, ffi.Double, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>),
      int Function(double, double, double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>)>('swe_houses_armc');

  late final swe_houses_armc_ex2 = _lib.lookupFunction<
      ffi.Int32 Function(
          ffi.Double, ffi.Double, ffi.Double, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>),
      int Function(
          double, double, double, int,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>)>('swe_houses_armc_ex2');

  late final swe_house_pos = _lib.lookupFunction<
      ffi.Double Function(ffi.Double, ffi.Double, ffi.Double, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      double Function(double, double, double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>)>('swe_house_pos');

  late final swe_gauquelin_sector = _lib.lookupFunction<
      ffi.Int32 Function(
          ffi.Double, ffi.Int32, ffi.Pointer<ffi.Uint8>, ffi.Int32, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Double, ffi.Double,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(
          double, int, ffi.Pointer<ffi.Uint8>, int, int,
          ffi.Pointer<ffi.Double>, double, double,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_gauquelin_sector');

  // --- Ayanamsa ---

  late final swe_get_ayanamsa_ut = _lib.lookupFunction<
      ffi.Double Function(ffi.Double),
      double Function(double)>('swe_get_ayanamsa_ut');

  late final swe_get_ayanamsa = _lib.lookupFunction<
      ffi.Double Function(ffi.Double),
      double Function(double)>('swe_get_ayanamsa');

  late final swe_get_ayanamsa_ex_ut = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>),
      int Function(double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>)>('swe_get_ayanamsa_ex_ut');

  late final swe_get_ayanamsa_ex = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>),
      int Function(double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>)>('swe_get_ayanamsa_ex');

  late final swe_get_ayanamsa_name = _lib.lookupFunction<
      ffi.Pointer<ffi.Uint8> Function(ffi.Int32),
      ffi.Pointer<ffi.Uint8> Function(int)>('swe_get_ayanamsa_name');

  // --- Names ---

  late final swe_get_planet_name = _lib.lookupFunction<
      ffi.Pointer<ffi.Uint8> Function(ffi.Int32, ffi.Pointer<ffi.Uint8>),
      ffi.Pointer<ffi.Uint8> Function(
          int, ffi.Pointer<ffi.Uint8>)>('swe_get_planet_name');

  late final swe_house_name = _lib.lookupFunction<
      ffi.Pointer<ffi.Uint8> Function(ffi.Int32),
      ffi.Pointer<ffi.Uint8> Function(int)>('swe_house_name');

  // --- Rise/set ---

  late final swe_rise_trans = _lib.lookupFunction<
      ffi.Int32 Function(
          ffi.Double,
          ffi.Int32,
          ffi.Pointer<ffi.Uint8>,
          ffi.Int32,
          ffi.Int32,
          ffi.Pointer<ffi.Double>,
          ffi.Double,
          ffi.Double,
          ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>),
      int Function(
          double,
          int,
          ffi.Pointer<ffi.Uint8>,
          int,
          int,
          ffi.Pointer<ffi.Double>,
          double,
          double,
          ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>)>('swe_rise_trans');

  // --- Fixed stars ---

  late final swe_fixstar2_ut = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<ffi.Uint8>, ffi.Double, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(ffi.Pointer<ffi.Uint8>, double, int,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_fixstar2_ut');

  late final swe_fixstar2 = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<ffi.Uint8>, ffi.Double, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(ffi.Pointer<ffi.Uint8>, double, int,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_fixstar2');

  late final swe_fixstar2_mag = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<ffi.Uint8>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>),
      int Function(ffi.Pointer<ffi.Uint8>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>)>('swe_fixstar2_mag');

  // --- Crossing functions ---

  late final swe_solcross_ut = _lib.lookupFunction<
      ffi.Double Function(ffi.Double, ffi.Double, ffi.Int32,
          ffi.Pointer<ffi.Uint8>),
      double Function(double, double, int,
          ffi.Pointer<ffi.Uint8>)>('swe_solcross_ut');

  late final swe_solcross = _lib.lookupFunction<
      ffi.Double Function(ffi.Double, ffi.Double, ffi.Int32,
          ffi.Pointer<ffi.Uint8>),
      double Function(double, double, int,
          ffi.Pointer<ffi.Uint8>)>('swe_solcross');

  late final swe_mooncross_ut = _lib.lookupFunction<
      ffi.Double Function(ffi.Double, ffi.Double, ffi.Int32,
          ffi.Pointer<ffi.Uint8>),
      double Function(double, double, int,
          ffi.Pointer<ffi.Uint8>)>('swe_mooncross_ut');

  late final swe_mooncross = _lib.lookupFunction<
      ffi.Double Function(ffi.Double, ffi.Double, ffi.Int32,
          ffi.Pointer<ffi.Uint8>),
      double Function(double, double, int,
          ffi.Pointer<ffi.Uint8>)>('swe_mooncross');

  late final swe_mooncross_node_ut = _lib.lookupFunction<
      ffi.Double Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      double Function(double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_mooncross_node_ut');

  late final swe_mooncross_node = _lib.lookupFunction<
      ffi.Double Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      double Function(double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_mooncross_node');

  late final swe_helio_cross_ut = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Int32, ffi.Double, ffi.Double, ffi.Int32,
          ffi.Int32, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(int, double, double, int,
          int, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_helio_cross_ut');

  late final swe_helio_cross = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Int32, ffi.Double, ffi.Double, ffi.Int32,
          ffi.Int32, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(int, double, double, int,
          int, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_helio_cross');

  // --- Eclipses ---

  late final swe_sol_eclipse_when_loc = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>, ffi.Int32,
          ffi.Pointer<ffi.Uint8>),
      int Function(double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>, int,
          ffi.Pointer<ffi.Uint8>)>('swe_sol_eclipse_when_loc');

  late final swe_sol_eclipse_when_glob = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Int32, ffi.Pointer<ffi.Uint8>),
      int Function(double, int, int, ffi.Pointer<ffi.Double>, int,
          ffi.Pointer<ffi.Uint8>)>('swe_sol_eclipse_when_glob');

  late final swe_sol_eclipse_how = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_sol_eclipse_how');

  late final swe_sol_eclipse_where = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_sol_eclipse_where');

  late final swe_lun_eclipse_when = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Int32, ffi.Pointer<ffi.Uint8>),
      int Function(double, int, int, ffi.Pointer<ffi.Double>, int,
          ffi.Pointer<ffi.Uint8>)>('swe_lun_eclipse_when');

  late final swe_lun_eclipse_when_loc = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>, ffi.Int32,
          ffi.Pointer<ffi.Uint8>),
      int Function(double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>, int,
          ffi.Pointer<ffi.Uint8>)>('swe_lun_eclipse_when_loc');

  late final swe_lun_eclipse_how = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_lun_eclipse_how');

  late final swe_lun_occult_when_loc = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Uint8>,
          ffi.Int32, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Int32, ffi.Pointer<ffi.Uint8>),
      int Function(double, int, ffi.Pointer<ffi.Uint8>, int,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, int,
          ffi.Pointer<ffi.Uint8>)>('swe_lun_occult_when_loc');

  late final swe_lun_occult_when_glob = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Uint8>,
          ffi.Int32, ffi.Int32, ffi.Pointer<ffi.Double>, ffi.Int32,
          ffi.Pointer<ffi.Uint8>),
      int Function(double, int, ffi.Pointer<ffi.Uint8>, int, int,
          ffi.Pointer<ffi.Double>, int,
          ffi.Pointer<ffi.Uint8>)>('swe_lun_occult_when_glob');

  late final swe_lun_occult_where = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Uint8>,
          ffi.Int32, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>),
      int Function(double, int, ffi.Pointer<ffi.Uint8>, int,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>)>('swe_lun_occult_where');

  // --- Utilities ---

  late final swe_degnorm = _lib.lookupFunction<
      ffi.Double Function(ffi.Double),
      double Function(double)>('swe_degnorm');

  // --- Horizon/Coordinates ---

  late final swe_azalt = _lib.lookupFunction<
      ffi.Void Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Double>,
          ffi.Double, ffi.Double, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>),
      void Function(double, int, ffi.Pointer<ffi.Double>,
          double, double, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>)>('swe_azalt');

  late final swe_azalt_rev = _lib.lookupFunction<
      ffi.Void Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>),
      void Function(double, int, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>)>('swe_azalt_rev');

  late final swe_cotrans = _lib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>, ffi.Double),
      void Function(ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>, double)>('swe_cotrans');

  late final swe_refrac = _lib.lookupFunction<
      ffi.Double Function(ffi.Double, ffi.Double, ffi.Double, ffi.Int32),
      double Function(double, double, double, int)>('swe_refrac');

  late final swe_refrac_extended = _lib.lookupFunction<
      ffi.Double Function(ffi.Double, ffi.Double, ffi.Double, ffi.Double,
          ffi.Double, ffi.Int32, ffi.Pointer<ffi.Double>),
      double Function(double, double, double, double,
          double, int, ffi.Pointer<ffi.Double>)>('swe_refrac_extended');

  // --- Time/Delta T ---

  late final swe_deltat = _lib.lookupFunction<
      ffi.Double Function(ffi.Double),
      double Function(double)>('swe_deltat');

  late final swe_deltat_ex = _lib.lookupFunction<
      ffi.Double Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Uint8>),
      double Function(double, int, ffi.Pointer<ffi.Uint8>)>('swe_deltat_ex');

  late final swe_time_equ = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(double, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_time_equ');

  late final swe_sidtime = _lib.lookupFunction<
      ffi.Double Function(ffi.Double),
      double Function(double)>('swe_sidtime');

  late final swe_sidtime0 = _lib.lookupFunction<
      ffi.Double Function(ffi.Double, ffi.Double, ffi.Double),
      double Function(double, double, double)>('swe_sidtime0');

  late final swe_lmt_to_lat = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Double, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(double, double, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_lmt_to_lat');

  late final swe_lat_to_lmt = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Double, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(double, double, ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_lat_to_lmt');

  late final swe_set_delta_t_userdef = _lib.lookupFunction<
      ffi.Void Function(ffi.Double),
      void Function(double)>('swe_set_delta_t_userdef');

  late final swe_get_tid_acc = _lib.lookupFunction<
      ffi.Double Function(),
      double Function()>('swe_get_tid_acc');

  late final swe_set_tid_acc = _lib.lookupFunction<
      ffi.Void Function(ffi.Double),
      void Function(double)>('swe_set_tid_acc');

  // --- More utilities ---

  late final swe_split_deg = _lib.lookupFunction<
      ffi.Void Function(ffi.Double, ffi.Int32, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Int32>),
      void Function(double, int, ffi.Pointer<ffi.Int32>,
          ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Int32>)>('swe_split_deg');

  late final swe_radnorm = _lib.lookupFunction<
      ffi.Double Function(ffi.Double),
      double Function(double)>('swe_radnorm');

  late final swe_deg_midp = _lib.lookupFunction<
      ffi.Double Function(ffi.Double, ffi.Double),
      double Function(double, double)>('swe_deg_midp');

  late final swe_rad_midp = _lib.lookupFunction<
      ffi.Double Function(ffi.Double, ffi.Double),
      double Function(double, double)>('swe_rad_midp');

  late final swe_difdegn = _lib.lookupFunction<
      ffi.Double Function(ffi.Double, ffi.Double),
      double Function(double, double)>('swe_difdegn');

  late final swe_difdeg2n = _lib.lookupFunction<
      ffi.Double Function(ffi.Double, ffi.Double),
      double Function(double, double)>('swe_difdeg2n');

  // --- Nodes & Apsides ---

  late final swe_nod_aps_ut = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Int32, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>),
      int Function(double, int, int, int,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>)>('swe_nod_aps_ut');

  late final swe_nod_aps = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Int32, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>),
      int Function(double, int, int, int,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>)>('swe_nod_aps');

  // --- Orbital elements ---

  late final swe_get_orbital_elements = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(double, int, int,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_get_orbital_elements');

  late final swe_orbit_max_min_true_distance = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(double, int, int,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_orbit_max_min_true_distance');

  // --- Phenomena ---

  late final swe_pheno_ut = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(double, int, int,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_pheno_ut');

  late final swe_pheno = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Int32, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(double, int, int,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_pheno');

  // --- Heliacal ---

  late final swe_heliacal_ut = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>, ffi.Int32, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(double, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>, int, int,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_heliacal_ut');

  late final swe_heliacal_pheno_ut = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>, ffi.Int32, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(double, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>, int, int,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_heliacal_pheno_ut');

  late final swe_vis_limit_mag = _lib.lookupFunction<
      ffi.Int32 Function(ffi.Double, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>, ffi.Int32,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(double, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Double>,
          ffi.Pointer<ffi.Uint8>, int,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_vis_limit_mag');

  // --- Rise/set true horizon ---

  late final swe_rise_trans_true_hor = _lib.lookupFunction<
      ffi.Int32 Function(
          ffi.Double, ffi.Int32, ffi.Pointer<ffi.Uint8>,
          ffi.Int32, ffi.Int32, ffi.Pointer<ffi.Double>,
          ffi.Double, ffi.Double, ffi.Double,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>),
      int Function(
          double, int, ffi.Pointer<ffi.Uint8>,
          int, int, ffi.Pointer<ffi.Double>,
          double, double, double,
          ffi.Pointer<ffi.Double>, ffi.Pointer<ffi.Uint8>)>('swe_rise_trans_true_hor');
}
