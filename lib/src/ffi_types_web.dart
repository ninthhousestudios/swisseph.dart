/// FFI types for web platforms (wasm_ffi).
///
/// This file is only loaded on web targets via conditional import in
/// `ffi_types.dart`. It will be fleshed out with wasm_ffi re-exports
/// when web support is implemented (Issue 3).
///
/// For now, it throws [UnsupportedError] to catch accidental web use
/// before the WASM build is ready.
// ignore_for_file: unused_element

/// Stub — web FFI support is not yet implemented.
///
/// The conditional import barrel (`ffi_types.dart`) routes here on web.
/// Once wasm_ffi integration lands, this file will re-export
/// `package:wasm_ffi/wasm_ffi.dart` and provide a `using` helper.
Never _unsupported() =>
    throw UnsupportedError('Web FFI not yet implemented — see Issue 3');
