import 'dart:io';
import 'package:hooks/hooks.dart';
import 'package:code_assets/code_assets.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:logging/logging.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    hierarchicalLoggingEnabled = true;
    final logger = Logger('swisseph_build')
      ..level = Level.ALL
      ..onRecord.listen((record) {
        print('${record.level.name}: ${record.message}');
      });

    final srcDir = _findSourceDir(input.packageRoot);
    logger.info('Swiss Ephemeris C source: $srcDir');

    final sources = [
      'sweph.c',
      'swephlib.c',
      'swecl.c',
      'swehouse.c',
      'swehel.c',
      'swejpl.c',
      'swemmoon.c',
      'swemplan.c',
      'swedate.c',
    ].map((f) => '$srcDir/$f').toList();

    final cBuilder = CBuilder.library(
      name: 'swisseph',
      assetName: 'swisseph',
      sources: sources,
      language: Language.c,
      optimizationLevel: OptimizationLevel.o2,
    );

    await cBuilder.run(input: input, output: output, logger: logger);
    logger.info('Build completed successfully');
  });
}

/// Find the Swiss Ephemeris C source directory.
/// Priority: SWISSEPH_SRC env var > vendored csrc/ > sibling directory.
String _findSourceDir(Uri packageRoot) {
  final envSrc = Platform.environment['SWISSEPH_SRC'];
  if (envSrc != null && Directory(envSrc).existsSync()) {
    return envSrc;
  }

  // Vendored C source inside the package.
  final packageDir = Directory.fromUri(packageRoot);
  final vendored = Directory('${packageDir.path}/csrc');
  if (vendored.existsSync() &&
      File('${vendored.path}/swephexp.h').existsSync()) {
    return vendored.path;
  }

  // Sibling swisseph/ directory (useful for local dev with newer C source).
  final parentDir = packageDir.parent;
  final sibling = Directory('${parentDir.path}/swisseph');
  if (sibling.existsSync() &&
      File('${sibling.path}/swephexp.h').existsSync()) {
    return sibling.path;
  }

  throw Exception(
    'Swiss Ephemeris C source not found. '
    'Set SWISSEPH_SRC environment variable or place swisseph/ as a sibling directory of swisseph.dart/.',
  );
}
