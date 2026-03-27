#!/usr/bin/env bash
# Build swisseph.wasm using Docker + Emscripten.
#
# Run from the repo root:
#   ./wasm/build.sh
#
# Output: assets/swisseph.{js,wasm}

set -euo pipefail
cd "$(dirname "$0")/.."

echo "Building swisseph WASM via Docker..."
docker build -t swisseph-wasm -f wasm/Dockerfile .

echo "Extracting build artifacts..."
mkdir -p assets
container=$(docker create swisseph-wasm)
docker cp "$container:/src/assets/swisseph.js" assets/swisseph.js
docker cp "$container:/src/assets/swisseph.wasm" assets/swisseph.wasm
docker rm "$container" > /dev/null

echo "Done:"
ls -lh assets/swisseph.js assets/swisseph.wasm
