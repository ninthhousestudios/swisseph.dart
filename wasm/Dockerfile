FROM emscripten/emsdk:3.1.51

WORKDIR /src

# Copy only what the build needs
COPY csrc/ csrc/
COPY wasm/exports.txt wasm/exports.txt
COPY wasm/Makefile wasm/Makefile

RUN mkdir -p assets && make -f wasm/Makefile
