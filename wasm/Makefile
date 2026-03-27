# Build Swiss Ephemeris as a standalone WASM module for wasm_ffi.
#
# Usage (Docker — recommended):
#   docker build -t swisseph-wasm -f wasm/Dockerfile .
#   docker run --rm -v $(pwd)/assets:/out swisseph-wasm cp /build/swisseph.wasm /out/
#
# Usage (local Emscripten):
#   make -f wasm/Makefile
#
# Output: assets/swisseph.{wasm,js}

CSRC     := csrc
SOURCES  := $(CSRC)/sweph.c \
            $(CSRC)/swephlib.c \
            $(CSRC)/swecl.c \
            $(CSRC)/swehouse.c \
            $(CSRC)/swehel.c \
            $(CSRC)/swejpl.c \
            $(CSRC)/swemmoon.c \
            $(CSRC)/swemplan.c \
            $(CSRC)/swedate.c

EXPORTS_FILE := wasm/exports.txt
OUTDIR       := assets
OUT_BASE     := $(OUTDIR)/swisseph

# Read exports from file, one per line, comma-separated for Emscripten
EXPORTED_FUNCTIONS := $(shell paste -sd, $(EXPORTS_FILE))

# Emscripten flags:
#   -O2                  optimise
#   -s MODULARIZE=1      wrap in a module factory (wasm_ffi expects this)
#   -s EXPORT_NAME=...   factory name
#   -s ALLOW_MEMORY_GROWTH=1  heap can grow
#   -s EXPORTED_FUNCTIONS=...  only export what we need + malloc/free
#   -s EXPORTED_RUNTIME_METHODS=...  JS helpers wasm_ffi uses
#   -s FILESYSTEM=0      no virtual FS (ephemeris data loaded differently on web)
#   -s ENVIRONMENT=web   web-only target
EMCC_FLAGS := -O2 \
    -s MODULARIZE=1 \
    -s EXPORT_NAME='SwissEph' \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s "EXPORTED_FUNCTIONS=[$(EXPORTED_FUNCTIONS)]" \
    -s "EXPORTED_RUNTIME_METHODS=['cwrap','ccall','getValue','setValue']" \
    -s FILESYSTEM=0 \
    -s ENVIRONMENT=web

.PHONY: all clean

all: $(OUT_BASE).js

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUT_BASE).js: $(SOURCES) $(EXPORTS_FILE) | $(OUTDIR)
	emcc $(SOURCES) $(EMCC_FLAGS) -o $@
	@echo "Built: $(OUT_BASE).js + $(OUT_BASE).wasm"
	@ls -lh $(OUT_BASE).js $(OUT_BASE).wasm

clean:
	rm -f $(OUT_BASE).js $(OUT_BASE).wasm
