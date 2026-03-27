/// Cross-platform FFI types.
///
/// On native platforms, re-exports `dart:ffi` + `package:ffi` utilities.
/// On web, re-exports `wasm_ffi` equivalents.
export 'ffi_types_native.dart'
    if (dart.library.js_interop) 'ffi_types_web.dart';
