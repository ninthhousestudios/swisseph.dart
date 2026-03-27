import 'package:wasm_ffi/ffi.dart';

/// Not supported on web — use [loadSwissEphAsync] instead.
Never loadSwissEph(String path) =>
    throw UnsupportedError('Web: use SwissEph.load() for async WASM loading');

/// Not supported on web — use [loadSwissEphAsync] instead.
Never findLibrary() =>
    throw UnsupportedError('Web: library search not available on web');

/// Load the Swiss Ephemeris WASM module asynchronously.
///
/// [modulePath] is the URL to the swisseph.js (Emscripten) or swisseph.wasm
/// (standalone) file served from your web app's assets.
///
/// Defaults to `'swisseph'` — wasm_ffi auto-detects the format by trying
/// .js then .wasm extensions.
Future<DynamicLibrary> loadSwissEphAsync(
    [String modulePath = 'swisseph']) async {
  return await DynamicLibrary.open(modulePath);
}
