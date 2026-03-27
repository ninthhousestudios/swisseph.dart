# Architecture — swisseph.dart 0.4

## Overview

Version 0.4 adds cross-platform support (native + web) to the existing
native-only FFI bindings. The core change is a **conditional import barrel**
architecture that routes all FFI types and library loading through
platform-specific files selected at compile time by Dart's conditional
import mechanism.

The public API is unchanged — all ~88 methods still live on the single
`SwissEph` class. Existing native code continues to work without
modification. A new async factory `SwissEph.load()` provides the
cross-platform entry point.

```
┌──────────────────────────────────────────────────────────────┐
│  Dart application code                                       │
│    import 'package:swisseph/swisseph.dart';                  │
│    final swe = await SwissEph.load();   // native or web     │
│    swe.calcUt(jd, seSun, seFlgMosEph);                       │
└───────────────────────┬──────────────────────────────────────┘
                        │
┌───────────────────────▼──────────────────────────────────────┐
│  SwissEph  (lib/src/swiss_eph.dart)                          │
│  Public API: ~88 methods                                     │
│  Imports ffi_types.dart (barrel) — no dart:ffi, no dart:io   │
│  Memory: Arena-scoped using()                                │
└───────────────────────┬──────────────────────────────────────┘
                        │
┌───────────────────────▼──────────────────────────────────────┐
│  SweBindings  (lib/src/bindings.dart)                        │
│  75 late final FFI function pointers                         │
│  Imports ffi_types.dart (barrel)                             │
└───────────────────────┬──────────────────────────────────────┘
                        │  ffi_types.dart → platform-specific
┌───────────────┬───────┴───────┐
│ Native        │ Web           │
│ dart:ffi      │ wasm_ffi      │
│ package:ffi   │ ffi_utils.dart│
│ .so/.dylib    │ .wasm module  │
└───────────────┴───────────────┘
```

## What changed from 0.2

### Problem

Version 0.2 imported `dart:ffi` and `dart:io` directly. This made the
package native-only — attempting to compile for web produced immediate
import failures. The Dart analyzer also checks all files under `lib/`
regardless of what the app actually imports, so even having `dart:io` in
a file that web code never reaches will cause analysis failures.

### Solution: conditional import barrels

Dart's conditional import syntax (`export 'a.dart' if (dart.library.x) 'b.dart'`)
lets a single import statement resolve to different files depending on the
target platform. We use two barrels:

1. **`ffi_types.dart`** — routes FFI types (`DynamicLibrary`, `Pointer`,
   `Int32`, `Double`, `Uint8`, `Arena`, `calloc`, `using`, etc.)
2. **`ffi_loader.dart`** — routes library loading functions
   (`loadSwissEph`, `loadSwissEphAsync`, `findLibrary`)

Each barrel has a native and web implementation file. The barrel defaults
to native and switches to web when `dart.library.js_interop` is available.

### Changes by file

| File | What changed | Why |
|------|-------------|-----|
| `swiss_eph.dart` | `import 'ffi_types.dart'` replaces `import 'dart:ffi'`; `import 'ffi_loader.dart'` replaces `import 'dart:io'`; new `SwissEph.load()` factory | Platform-agnostic |
| `bindings.dart` | `import 'ffi_types.dart' as ffi` replaces `import 'dart:ffi' as ffi` | Platform-agnostic |
| `utf8_compat.dart` | `import 'ffi_types.dart'` replaces `import 'dart:ffi'` | Platform-agnostic |
| `ffi_types.dart` | **New.** Conditional import barrel | Routes to native or web FFI types |
| `ffi_types_native.dart` | **New.** Re-exports `dart:ffi` + `package:ffi` utilities | Native FFI types |
| `ffi_types_web.dart` | **New.** Re-exports `package:wasm_ffi` types + custom `using()` | Web FFI types |
| `ffi_loader.dart` | **New.** Conditional import barrel | Routes to native or web loader |
| `ffi_loader_native.dart` | **New.** `loadSwissEph()`, `findLibrary()`, `loadSwissEphAsync()` | Extracted from `swiss_eph.dart`; uses `dart:io` |
| `ffi_loader_web.dart` | **New.** `loadSwissEphAsync()` via `wasm_ffi` `DynamicLibrary.open()` | Web WASM loading |
| All 88 bindings | `ffi.Char` → `ffi.Uint8` | `wasm_ffi` has no `Char` type |
| All methods | `calloc`/`free`/`try`/`finally` → Arena-scoped `using()` | Cross-platform memory management |
| `pubspec.yaml` | Added `wasm_ffi: ^2.3.0` dependency | Web platform support |

### New files (WASM build)

| File | Purpose |
|------|---------|
| `wasm/Makefile` | Emscripten build rules |
| `wasm/Dockerfile` | Docker image with emsdk 3.1.51 |
| `wasm/build.sh` | Convenience script: docker build + artifact extraction |
| `wasm/exports.txt` | 88 `_swe_*` functions + `_malloc` + `_free` |
| `assets/swisseph.js` | Emscripten JS glue (30 KB) |
| `assets/swisseph.wasm` | Compiled WASM module (512 KB) |

## Conditional import barrel architecture

### How Dart conditional imports work

```dart
export 'ffi_types_native.dart'
    if (dart.library.js_interop) 'ffi_types_web.dart';
```

The Dart compiler evaluates the condition at compile time:
- **Native targets** (CLI, Flutter mobile/desktop): `dart.library.js_interop`
  is false → imports `ffi_types_native.dart`
- **Web targets** (dart2js, dart2wasm): `dart.library.js_interop` is true →
  imports `ffi_types_web.dart`

The default (first file) is native. This matters because the Dart analyzer
checks all files under `lib/` as standalone compilation units. By defaulting
to native, `dart analyze` on the developer's machine sees the native types.
The web files must still be syntactically valid and resolvable (their imports
must exist), but they aren't analyzed as the primary target.

### ffi_types barrel

**`ffi_types_native.dart`** re-exports:
- `dart:ffi` — `DynamicLibrary`, `Pointer`, `Int32`, `Double`, `Uint8`,
  `NativeFunction`, `Void`, etc.
- `package:ffi` — `Arena`, `calloc`, `using`

**`ffi_types_web.dart`** re-exports:
- `package:wasm_ffi/ffi.dart` — mirrors all `dart:ffi` types for WASM
- `package:wasm_ffi/ffi_utils.dart` — `Arena`, `calloc`
- Custom `using()` function (see below)

The key insight: `wasm_ffi` mirrors the `dart:ffi` API almost exactly.
`DynamicLibrary`, `Pointer<T>`, `Int32`, `Double`, `Uint8`, and
`lookupFunction` all exist with compatible signatures. This means
`bindings.dart` and `swiss_eph.dart` work unchanged on both platforms
after switching from `import 'dart:ffi'` to `import 'ffi_types.dart'`.

### ffi_loader barrel

**`ffi_loader_native.dart`** provides:
- `loadSwissEph(String path)` — wraps `DynamicLibrary.open()` (sync)
- `findLibrary()` — searches `.dart_tool/` for the compiled `.so`/`.dylib`/`.dll`
- `loadSwissEphAsync([String? _])` — thin async wrapper for API uniformity

**`ffi_loader_web.dart`** provides:
- `loadSwissEph()` / `findLibrary()` — throw `UnsupportedError` (web is async-only)
- `loadSwissEphAsync([String modulePath])` — calls `DynamicLibrary.open(modulePath)`
  which is async in `wasm_ffi` (it handles module detection, memory init,
  and WASM compilation internally)

This separation means `swiss_eph.dart` never imports `dart:io`. The
`dart:io` dependency lives only in `ffi_loader_native.dart`, which web
targets never see.

### Why not `dart:ffi` conditional on `dart.library.ffi`?

We originally tried:

```dart
export 'ffi_types_web.dart'
    if (dart.library.ffi) 'ffi_types_native.dart';
```

This failed: the analyzer defaults to the *first* file when it cannot
determine the target. Defaulting to the web file meant the analyzer on a
native developer machine tried to resolve `wasm_ffi` imports as the
primary target, producing hundreds of undefined-class errors. Flipping
the default to native and conditioning on `dart.library.js_interop`
resolved this.

## Char → Uint8 migration

### Problem

`dart:ffi` has both `Char` and `Uint8` as native types. `wasm_ffi` only
has `Uint8` — it doesn't implement `Char`. The Swiss Ephemeris C API uses
`char` for string buffers (error messages, star names, paths).

### Solution

All 88 bindings in `bindings.dart` were migrated from `ffi.Char` to
`ffi.Uint8`. Since C `char` is an 8-bit type and all string data in the
Swiss Ephemeris is ASCII/UTF-8, `Uint8` is semantically identical.

This required corresponding changes in `utf8_compat.dart`, which provides
`Pointer<Uint8>.toDartString()` and `String.toNativeString()` extensions
that handle UTF-8 encoding/decoding without depending on `package:ffi`'s
`Utf8` type (which `wasm_ffi` doesn't have).

## Memory management: calloc/free → Arena using()

### Problem (0.2 pattern)

```dart
ReturnType method(args) {
  final ptr = calloc<Double>(6);
  final serr = calloc<Uint8>(256);
  try {
    _bind.some_function(ptr, serr);
    return ReturnType(/* read from ptr */);
  } finally {
    calloc.free(serr);
    calloc.free(ptr);
  }
}
```

This works on native but has a problem: `calloc.free()` doesn't exist in
`wasm_ffi`. The `wasm_ffi` package provides `Arena` and `calloc` for
allocation, but cleanup uses `arena.releaseAll()`, not individual `free()`
calls.

### Solution (0.4 pattern)

```dart
ReturnType method(args) {
  return using((arena) {
    final ptr = arena<Double>(6);
    final serr = arena<Uint8>(256);
    _bind.some_function(ptr, serr);
    return ReturnType(/* read from ptr */);
  });
}
```

`using()` creates an `Arena`, passes it to the callback, and calls
`arena.releaseAll()` in a `finally` block. This works identically on
both platforms:

- **Native:** `using()` from `package:ffi` — allocates via `calloc`,
  tracks pointers, frees all on exit
- **Web:** custom `using()` in `ffi_types_web.dart` — same behavior
  via `wasm_ffi`'s `Arena`

The custom `using()` for web is necessary because `wasm_ffi` exports
`Arena` and `calloc` from `ffi_utils.dart` but doesn't provide a
standalone `using()` function matching `package:ffi`'s signature.

## SwissEph constructors

### Existing (native-only, preserved)

```dart
SwissEph(String libraryPath)   // explicit path to .so/.dylib/.dll
SwissEph.find()                // search .dart_tool/ automatically
```

These still work unchanged on native. On web they throw
`UnsupportedError` because they call the synchronous loader.

### New (cross-platform)

```dart
static Future<SwissEph> load() async {
  final lib = await loader.loadSwissEphAsync();
  return SwissEph._fromLibrary(lib);
}
```

`SwissEph.load()` is async because WASM module loading is inherently
async (compilation + instantiation). On native, the async wrapper is
trivial (synchronous open wrapped in a future). The private
`SwissEph._fromLibrary()` constructor takes an already-opened
`DynamicLibrary`, avoiding duplication of initialization logic.

## WASM build infrastructure

### Why Emscripten?

The `wasm_ffi` Dart package expects an Emscripten-compiled module with
`MODULARIZE=1`. Emscripten generates both the `.wasm` binary and a `.js`
glue file that handles module instantiation, memory management, and
function exports. The `wasm_ffi` `DynamicLibrary.open()` loads this
module and provides `dart:ffi`-compatible accessors.

### Build configuration

The Makefile compiles all 9 Swiss Ephemeris C source files with these
Emscripten flags:

| Flag | Purpose |
|------|---------|
| `-O2` | Optimization level |
| `MODULARIZE=1` | Wrap output in a module factory function |
| `EXPORT_NAME='SwissEph'` | Factory function name |
| `ALLOW_MEMORY_GROWTH=1` | Heap can grow beyond initial allocation |
| `EXPORTED_FUNCTIONS=[...]` | 88 `_swe_*` functions + `_malloc` + `_free` |
| `EXPORTED_RUNTIME_METHODS` | `cwrap`, `ccall`, `getValue`, `setValue` |
| `FILESYSTEM=0` | No Emscripten virtual filesystem |
| `ENVIRONMENT=web` | Web-only target (no Node.js support code) |

### Why FILESYSTEM=0?

The Swiss Ephemeris C library reads `.se1` data files via the filesystem.
On web there is no filesystem. Rather than emulating one (which adds
significant code size), we disable it entirely. This means:

- Web calculations use **Moshier ephemeris only** (~1 arcsecond accuracy)
- `setEphePath()` is a no-op on web
- `seFlgSwiEph` and `seFlgJplEph` flags fall back to Moshier on web

For most astrological applications, Moshier accuracy is sufficient.

### Docker build

The build is containerized to avoid requiring a local Emscripten
installation:

```
wasm/Dockerfile  → FROM emscripten/emsdk:3.1.51
                   COPY csrc/ and wasm/ build files
                   RUN make -f wasm/Makefile

wasm/build.sh    → docker build + docker cp artifacts to assets/
```

The WASM assets are pre-built and committed to the repository. Rebuilding
is only necessary when the C source changes.

### Output

| File | Size | Contents |
|------|------|----------|
| `assets/swisseph.js` | 30 KB | Emscripten JS glue + module factory |
| `assets/swisseph.wasm` | 512 KB | Compiled WASM binary |

## wasm_ffi integration

### Package choice

[`wasm_ffi`](https://pub.dev/packages/wasm_ffi) (v2.3.0) was chosen
because it mirrors the `dart:ffi` API — same type names, same
`lookupFunction` signature, same `Pointer<T>` operations. This
minimizes the changes needed in existing code: only the import path
changes, not the code itself.

### API surface used

From `package:wasm_ffi/ffi.dart`:
- `DynamicLibrary` (with async `open()`)
- `Pointer<T>`, `Uint8`, `Int32`, `Double`, `Void`
- `NativeFunction`, `lookupFunction`
- `Allocator`

From `package:wasm_ffi/ffi_utils.dart`:
- `Arena`
- `calloc`

### Key difference: async DynamicLibrary.open()

In `dart:ffi`, `DynamicLibrary.open()` is synchronous — the OS linker
maps the `.so` immediately. In `wasm_ffi`, it's asynchronous — the
browser must fetch, compile, and instantiate the WASM module. This is
why `SwissEph.load()` is `async` and returns `Future<SwissEph>`.

Once the library is opened, all subsequent operations (lookupFunction,
pointer operations, etc.) are synchronous on both platforms.

## utf8_compat.dart

### Why custom string extensions?

`package:ffi` provides `Utf8` type and `toNativeUtf8()`/`toDartString()`
extensions. `wasm_ffi` doesn't have these. Rather than conditionally
importing two different string-handling approaches, we wrote
platform-agnostic string extensions that work with `Pointer<Uint8>`:

```dart
extension Utf8Pointer on Pointer<Uint8> {
  String toDartString({int? length}) { ... }
}

extension StringNative on String {
  Pointer<Uint8> toNativeString(Allocator allocator, [int? size]) { ... }
}
```

These use `dart:convert`'s `utf8` codec directly and work identically on
both platforms. The `toNativeString()` extension takes an `Allocator`
parameter (typically the `Arena` from `using()`), integrating naturally
with the Arena-scoped memory pattern.

## File structure (0.4)

```
swisseph.dart/
├── assets/                        # Pre-built WASM module
│   ├── swisseph.js                # Emscripten JS glue (30 KB)
│   └── swisseph.wasm              # WASM binary (512 KB)
├── csrc/                          # Vendored Swiss Ephemeris C source
├── ephe/                          # Bundled .se1 ephemeris data files
├── hook/
│   └── build.dart                 # Native asset build hook (CBuilder)
├── lib/
│   ├── swisseph.dart              # Barrel export
│   └── src/
│       ├── bindings.dart          # SweBindings — 75 raw FFI lookups
│       ├── swiss_eph.dart         # SwissEph — ~88 public methods
│       ├── types.dart             # Result types (all immutable)
│       ├── constants.dart         # ~250 integer constants from swephexp.h
│       ├── utf8_compat.dart       # Platform-agnostic UTF-8 string extensions
│       ├── ffi_types.dart         # Conditional import barrel (types)
│       ├── ffi_types_native.dart  # Re-exports dart:ffi + package:ffi
│       ├── ffi_types_web.dart     # Re-exports wasm_ffi + custom using()
│       ├── ffi_loader.dart        # Conditional import barrel (loader)
│       ├── ffi_loader_native.dart # Native library loading (dart:io)
│       └── ffi_loader_web.dart    # Web WASM loading (wasm_ffi)
├── wasm/                          # WASM build infrastructure
│   ├── Dockerfile                 # Emscripten Docker build
│   ├── Makefile                   # Emscripten build rules
│   ├── build.sh                   # Convenience build script
│   └── exports.txt                # 88 exported C function names
├── test/
│   ├── date_test.dart
│   ├── calc_test.dart
│   ├── houses_test.dart
│   ├── ayanamsa_test.dart
│   ├── isolate_test.dart
│   ├── load_test.dart             # SwissEph.load() async factory test
│   └── libaditya-validation/
├── example/
│   └── example.dart
├── doc/
│   ├── architecture-0.1.md
│   ├── architecture-0.2.md
│   └── architecture-0.4.md        # This file
└── pubspec.yaml
```

## Dependencies (0.4)

| Package | Purpose | Why in `dependencies` |
|---------|---------|----------------------|
| `ffi` | `Arena`, `calloc`, `using` on native | Runtime FFI support |
| `wasm_ffi` | `DynamicLibrary`, `Pointer`, `Arena`, `calloc` on web | Runtime web FFI |
| `logging` | Build hook logging | Used by build hook |
| `hooks` | Build hook framework | Build-time execution |
| `code_assets` | Native asset declaration | Build-time execution |
| `native_toolchain_c` | C compiler invocation | Build-time execution |
| `test` (dev) | Test framework | Test-time only |

## Design decisions

### Why conditional imports, not a wrapper package?

Alternatives considered:
1. **Abstract interface + platform implementations** — More OOP-correct
   but adds a layer of indirection over every FFI call. Would require
   wrapping `Pointer<T>`, `DynamicLibrary`, and all type operations.
   Significant performance overhead and code complexity.
2. **Separate packages** (`swisseph` + `swisseph_web`) — Splits the
   codebase, doubles maintenance, and forces consumers to choose at
   dependency time rather than compile time.
3. **Conditional import barrels** (chosen) — Zero runtime overhead, one
   codebase, platform selection at compile time. The `wasm_ffi` package
   already mirrors `dart:ffi`'s API, so the barrel just redirects imports.

### Why Arena instead of calloc/free?

Version 0.2 used explicit `calloc`/`free` in `try`/`finally`. This worked
well on native but `calloc.free()` is not available in `wasm_ffi`. The
Arena pattern works identically on both platforms and is arguably cleaner
— a single `using()` block replaces matched alloc/free pairs, eliminating
the possibility of forgetting a `free()` in a multi-allocation method.

### Why pre-built WASM assets?

Building WASM requires Emscripten (1+ GB toolchain). Committing the
pre-built artifacts means:
- Consumers don't need Emscripten installed
- `dart pub get` doesn't trigger a WASM build
- Reproducible builds via the Docker image (emsdk 3.1.51)
- Rebuild only when C source changes

### Why Moshier-only on web?

The Swiss Ephemeris `.se1` data files require filesystem access. The
Emscripten virtual filesystem (`FILESYSTEM=1`) would add code size and
complexity for something that doesn't map well to the web model. Moshier
mode is self-contained (computed, not file-based) and provides ~1 arcsecond
accuracy — sufficient for most astrological applications.

A future version could support loading ephemeris data via HTTP fetch into
an Emscripten memory filesystem, but this would require C-side changes
or Emscripten FS configuration beyond the current scope.

## What's unchanged from 0.2

Everything not listed above is identical to the 0.2 architecture:

- **Public API** — same ~88 methods on `SwissEph`, same result types,
  same constants
- **Build hook** — `hook/build.dart` still compiles C source via
  `CBuilder` for native targets
- **Bindings** — same 75 `late final` lookups (with `Char` → `Uint8`)
- **Error handling** — same three C error patterns (negative return,
  JD sentinel, integer return code)
- **Isolate safety** — same copy-the-.so-per-isolate pattern on native
- **Tests** — existing 26 unit tests + 545-value cross-validation unchanged
- **Ephemeris data** — same bundled `.se1` files in `ephe/`

See `doc/architecture-0.2.md` for details on these unchanged aspects.
