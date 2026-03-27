import 'dart:io';

import 'ffi_types.dart';

/// Load the Swiss Ephemeris shared library from an explicit [path].
DynamicLibrary loadSwissEph(String path) => DynamicLibrary.open(path);

/// Load the Swiss Ephemeris library asynchronously.
///
/// On native, this is a thin wrapper around [findLibrary] + [loadSwissEph].
/// Provides a unified async API matching the web loader.
Future<DynamicLibrary> loadSwissEphAsync([String? _]) async {
  return loadSwissEph(findLibrary());
}

/// Search for the compiled Swiss Ephemeris shared library.
///
/// Searches .dart_tool/ recursively for libswisseph.so, libswisseph.dylib,
/// or swisseph.dll.
/// Returns the absolute path. Throws [StateError] if not found.
String findLibrary() {
  final dartTool = Directory('.dart_tool');
  if (dartTool.existsSync()) {
    for (final entity in dartTool.listSync(recursive: true)) {
      if (entity is File &&
          (entity.path.endsWith('libswisseph.so') ||
              entity.path.endsWith('libswisseph.dylib') ||
              entity.path.endsWith('swisseph.dll'))) {
        return entity.path;
      }
    }
  }
  throw StateError(
    'libswisseph not found. Run "dart pub get" to trigger the build hook, '
    'or pass an explicit path to SwissEph().',
  );
}
