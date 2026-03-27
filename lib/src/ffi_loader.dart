/// Cross-platform library loader.
///
/// On native platforms, provides [findLibrary] and [loadSwissEph].
/// On web, throws [UnsupportedError] until WASM support lands.
export 'ffi_loader_native.dart'
    if (dart.library.js_interop) 'ffi_loader_web.dart';
