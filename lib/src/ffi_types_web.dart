/// FFI types for web platforms (wasm_ffi).
///
/// Re-exports wasm_ffi types and provides a [using] helper matching
/// package:ffi's API.
export 'package:wasm_ffi/ffi.dart';
export 'package:wasm_ffi/ffi_utils.dart' show Arena, calloc;

import 'package:wasm_ffi/ffi.dart' show Allocator;
import 'package:wasm_ffi/ffi_utils.dart' show Arena, calloc;

/// Run [computation] with an [Arena] allocator that frees everything on return.
///
/// Mirrors `package:ffi`'s `using` function.
R using<R>(R Function(Arena) computation,
    [Allocator wrappedAllocator = calloc]) {
  final arena = Arena(wrappedAllocator);
  try {
    return computation(arena);
  } finally {
    arena.releaseAll();
  }
}
