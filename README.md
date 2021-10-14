# dmd-fe-wasm-wrapper

## Table of Contents

- [dmd-fe-wasm-wrapper](#dmd-fe-wasm-wrapper)
  - [Table of Contents](#table-of-contents)
  - [Description](#description)
  - [Compilation](#compilation)
    - [Prerequisites](#prerequisites)
    - [1. Create your work directory](#1-create-your-work-directory)
    - [2. Download the WASI SDK](#2-download-the-wasi-sdk)
    - [3. Download and build a customized version of LDC](#3-download-and-build-a-customized-version-of-ldc)
      - [!!! IMPORTANT !!!](#-important-)
    - [4. Add your newly compiled version of LDC to $PATH](#4-add-your-newly-compiled-version-of-ldc-to-path)
    - [5. Build a custom version of DRuntime](#5-build-a-custom-version-of-druntime)
    - [6. Patch your ldc2.conf](#6-patch-your-ldc2conf)
    - [7. Clone the repo](#7-clone-the-repo)
    - [8. Build the repo](#8-build-the-repo)
      - [Note: If this build fails (due to dmd complaining about VERSION), you should run:](#note-if-this-build-fails-due-to-dmd-complaining-about-version-you-should-run)
    - [9. Test the WebAssembly file](#9-test-the-webassembly-file)
  
## Description
This is a proof-of-concept, showing that the DMD-FE can be fully thrown into a WebAssembly module.

## Compilation

### Prerequisites

- New-ish version of either LDC/DMD (v1.25.0+ / v2.096.0+ are recommended)
- LLVM 10.0.1
- wget
- Git
- bash
- wasmer
- Make / CMake
- A working C++ compiler

### 1. Create your work directory

First, let's start by making a work directory. I'll name mine `dmd-fe-wasm`, but any name works.

```bash
mkdir dmd-fe-wasm && cd dmd-fe-wasm
export DMD_FE_WORKDIR=$(pwd)
```

### 2. Download the WASI SDK

Now, we'll want to get a copy of the WASI SDK. I have only tested 10.0, but 12.0 should *hopefully* work.

```bash
wget https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-10/wasi-sdk-10.0-linux.tar.gz
tar -xf wasi-sdk-10.0-linux.tar.gz
export WASI_SDK_PREFIX=$(pwd)/wasi-sdk-10.0
```

### 3. Download and build a customized version of LDC

Now, we want to pull and build a customized copy of LDC (LLVM D Compiler)'s source code.

```bash
git clone -b wasm https://github.com/skoppe/ldc.git ldc-wasm
cd ldc-wasm
export LDC_SOURCE_DIR=$(pwd)
mkdir -p build && cd build
cmake -DBUILD_SHARED_LIBS=OFF .. && make -j $(nproc)
```

This may take a while, as we have to fully build a copy of the compiler, but it's worth waiting.

#### !!! IMPORTANT !!!

If you have multiple installations of LLVM (like me), you will need to set `LLVM_CONFIG` and `LLVM_INC_DIR` when you call CMake.

This is done like so:

```bash
cmake -DLLVM_CONFIG=LLVM_DIR/bin/llvm-config -DLLVM_INC_DIR=LLVM_DIR/include -DBUILD_SHARED_LIBS=OFF ..
```

where LLVM_DIR is the path to your LLVM installation (that you want to use -- make sure that it is 10.0.1!)

For me, this command looks like:

```bash
cmake -DLLVM_CONFIG=/usr/lib/llvm/10/bin/llvm-config -DLLVM_INC_DIR=/usr/lib/llvm/10/include -DBUILD_SHARED_LIBS=OFF ..
```

### 4. Add your newly compiled version of LDC to $PATH

Great! You now have a (hopefully) functioning copy of LDC. Let's add it to your path with this command:
```bash
export PATH="$(pwd)/bin:$PATH"
```

### 5. Build a custom version of DRuntime

Now, we'll want to build a custom version of DRuntime (built specially for WebAssembly). Run these commands as follows:

```bash
cd bin
./ldc-build-runtime -j $(nproc) \
"--dFlags=-mtriple=wasm32-wasi" \
--ldcSrcDir=$LDC_SOURCE_DIR \
CMAKE_TOOLCHAIN_FILE="$WASI_SDK_PREFIX/share/cmake/wasi-sdk.cmake" \
WASI_SDK_PREFIX=$WASI_SDK_PREFIX \
BUILD_SHARED_LIBS=OFF \
--linkerFlags="-Wl,--allow-undefined;-Wl,--export=__heap_base;-Wl,--export=__data_end"
```

This will take a minute, but should produce a working version of DRuntime / Phobos.

### 6. Patch your ldc2.conf

The ldc2.conf that comes with the LDC build worked to build the runtime, but we need to now link against it (and other various bits). As such, you'll need to patch `ldc2.conf`.

To patch it, I've conceived this *massive* hack of a command (note: this *MAY* break in the future). Run:

```shell
sed -i 'H;1h;$!d;x; s/^"\^wasm.*\(\n*.*\)*//mg' ldc2.conf
```

That command was to just remove the previous defaults -- now we want to add new content in:

```shell
cat >>ldc2.conf <<EOF
"^wasm(32|64)-":
{
    switches = [
        "-defaultlib=c,phobos2-ldc,druntime-ldc",
        "-L-lm",
        "-L-lclang_rt.builtins-wasm32",
        "-L-lc-printscan-long-double",
    ];
    lib-dirs = [
        "$(pwd)/ldc-build-runtime.tmp/lib",
        "$WASI_SDK_PREFIX/lib/clang/10.0.0/lib/wasi",
        "$WASI_SDK_PREFIX/share/wasi-sysroot/lib/wasm32-wasi",
    ];
};
EOF
```

### 7. Clone the repo

Run:
```bash
cd $DMD_FE_WORKDIR
git clone --recurse-submodules https://github.com/hatf0/dmd-fe-wasm-wrapper.git
```

### 8. Build the repo

Run:
```bash
cd dmd-fe-wasm-wrapper
dub build --compiler=ldc2 --arch=wasm32-wasi
```

#### Note: If this build fails (due to dmd complaining about VERSION), you should run:
```bash
cd subprojects/dmd
dub build
cd ../../
```

### 9. Test the WebAssembly file

Run:
```bash
wasmer run fe-wrapper.wasm --mapdir /:$LDC_SOURCE_DIR/runtime/druntime/src
```

and you should have some diagnostic output, then pleasantly greeted with the contents of our test file (which has passed parsing / sema).

Feel free to iterate upon app.d -- this is just how to get started with this repo!
