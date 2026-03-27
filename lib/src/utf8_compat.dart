import 'dart:convert';
import 'dart:typed_data';

import 'ffi_types.dart';

/// Extension to read a null-terminated UTF-8 string from native memory.
extension Utf8Pointer on Pointer<Uint8> {
  /// Decode a null-terminated UTF-8 string from this pointer.
  ///
  /// If [length] is provided, reads exactly that many bytes (no null scan).
  String toDartString({int? length}) {
    if (length != null) return utf8.decode(asTypedList(length));
    int len = 0;
    while (this[len] != 0) {
      len++;
    }
    return utf8.decode(asTypedList(len));
  }
}

/// Extension to write a Dart string to native memory as null-terminated UTF-8.
extension StringNative on String {
  /// Encode this string as null-terminated UTF-8 into newly allocated memory.
  ///
  /// If [size] is given, the buffer is that many bytes (string is truncated
  /// if needed). Otherwise the buffer is exactly `utf8.length + 1`.
  Pointer<Uint8> toNativeString(Allocator allocator, [int? size]) {
    final units = utf8.encode(this);
    size ??= units.length + 1;
    final Pointer<Uint8> result = allocator<Uint8>(size);
    final Uint8List nativeString = result.asTypedList(size);
    final copyLen = units.length < size ? units.length : size - 1;
    nativeString.setAll(0, units.sublist(0, copyLen));
    nativeString[copyLen] = 0;
    return result;
  }
}
