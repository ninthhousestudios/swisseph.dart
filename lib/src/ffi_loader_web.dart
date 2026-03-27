/// Web library loader — stub until WASM build is ready (Issue 3).
///
/// This file is only loaded on web targets via conditional import in
/// `ffi_loader.dart`.

Never loadSwissEph(String path) =>
    throw UnsupportedError('Web: use SwissEph.web() for WASM loading');

Never findLibrary() =>
    throw UnsupportedError('Web: use SwissEph.web() for WASM loading');
