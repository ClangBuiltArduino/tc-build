#!/bin/bash
# Copyright (C) 2025 ClangBuiltArduino
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}"/../common/utils.sh &>/dev/null || source utils.sh # Include basic common utilities
set -euo pipefail

# Set flags for static linking
COMMON_FLAGS+=("-static")
COMMON_LDFLAGS+=(
    "-static"
)

# Set flags to use libs from stage1.
COMMON_LDFLAGS+=(
    "-L${INSTALL_DIR}/stage1/lib"
    "-L${INSTALL_DIR}/stage1/lib/x86_64-unknown-linux-gnu/"
)

# Set flags for using LLVM stdlibs.
COMMON_LDFLAGS+=(
    "-Wl,--as-needed"
    "-Wl,-Bstatic"
    "-stdlib=libc++"
    "--unwindlib=libunwind"
    "-lc++"
    "-lc++abi"
)

# Detect if host has musl or glibc for configuring
if ! getconf GNU_LIBC_VERSION >/dev/null 2>&1; then
    # https://wiki.musl-libc.org/functional-differences-from-glibc.html#Thread-stack-size
    COMMON_LDFLAGS+=("-Wl,-z,stack-size=8388608") # 8MB stack size
fi

# Prepare environment
prep_env

# Get source mode from args.
parse_llvm_source_args "$@"

# Get sources
cd "${SOURCE_DIR}"
LLVM_SDIR="$(get_llvm_source)"
cd "${LLVM_SDIR}"
apply_llvm_patches
cd -

# Use tools exclusively from bootstrap build if possible.
export PATH="$INSTALL_DIR/stage1/bin:$PATH"
export LD_LIBRARY_PATH="$INSTALL_DIR/stage1/lib/x86_64-unknown-linux-gnu:$INSTALL_DIR/stage1/lib"

# Build stage2
init_build_dir "${BUILD_DIR}/stage2"
cmake -G "Ninja" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}/install" \
    -DCLANG_VENDOR="ClangBuiltArduino" \
    -DLLD_VENDOR="ClangBuiltArduino" \
    -DBUG_REPORT_URL="https://github.com/ClangBuiltArduino/issue-tracker/issues" \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_TARGETS_TO_BUILD="AVR;ARM" \
    -DLLVM_DEFAULT_TARGET_TRIPLE="arm-none-eabi" \
    -DLLVM_ENABLE_PIC=ON \
    -DLIBCLANG_BUILD_STATIC=ON \
    -DLLVM_BUILD_SHARED_LIBS=OFF \
    -DLLVM_BUILD_STATIC=ON \
    -DLLVM_CCACHE_BUILD=ON \
    -DLLVM_DISTRIBUTION_COMPONENTS="clang-resource-headers;clang;lld;llvm-addr2line;llvm-as;llvm-ar;llvm-nm;llvm-objcopy;llvm-objdump;llvm-ranlib;llvm-readobj;llvm-readelf;llvm-size;llvm-strings;llvm-strip;llvm-symbolizer" \
    -DLLVM_BUILD_UTILS=OFF \
    -DLLVM_ENABLE_BACKTRACES=OFF \
    -DLLVM_ENABLE_BINDINGS=OFF \
    -DLLVM_ENABLE_LIBCXX=ON \
    -DLLVM_ENABLE_LIBXML2=OFF \
    -DLLVM_ENABLE_LLD=ON \
    -DLLVM_ENABLE_LTO=THIN \
    -DLLVM_ENABLE_OCAMLDOC=OFF \
    -DLLVM_EXTERNAL_CLANG_TOOLS_EXTRA_SOURCE_DIR='' \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_INCLUDE_DOCS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_UTILS=OFF \
    -DLLVM_LINK_LLVM_DYLIB=OFF \
    -DLLVM_STATIC_LINK_CXX_STDLIB=ON \
    -DCLANG_BUILD_TOOLS=OFF \
    -DCLANG_DEFAULT_CXX_STDLIB="libc++" \
    -DCLANG_DEFAULT_OBJCOPY="llvm-objcopy" \
    -DCLANG_ENABLE_ARCMT=OFF \
    -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
    -DCLANG_INCLUDE_DOCS=OFF \
    -DLLVM_ENABLE_ZLIB=ON \
    -DLLVM_ENABLE_ZSTD=ON \
    -DLLVM_USE_STATIC_ZSTD=ON \
    -DZLIB_INCLUDE_DIR="${INSTALL_DIR}/zlib/include" \
    -DZLIB_LIBRARY="${INSTALL_DIR}/zlib/lib/libz.a" \
    -Dzstd_INCLUDE_DIR="${INSTALL_DIR}/zstd/include" \
    -Dzstd_LIBRARY="${INSTALL_DIR}/zstd/lib/libzstd.a" \
    -DCMAKE_C_COMPILER="${INSTALL_DIR}/stage1/bin/clang" \
    -DCMAKE_CXX_COMPILER="${INSTALL_DIR}/stage1/bin/clang++" \
    -DCMAKE_C_FLAGS="${COMMON_FLAGS[*]}" \
    -DCMAKE_CXX_FLAGS="${COMMON_FLAGS[*]} -stdlib=libc++" \
    -DCMAKE_EXE_LINKER_FLAGS="${COMMON_LDFLAGS[*]}" \
    -DCMAKE_MODULE_LINKER_FLAGS="${COMMON_LDFLAGS[*]}" \
    -DCMAKE_SHARED_LINKER_FLAGS="${COMMON_LDFLAGS[*]}" \
    -DLLVM_PARALLEL_COMPILE_JOBS="$(nproc --all)" \
    -DLLVM_PARALLEL_LINK_JOBS="$(nproc --all)" \
    "${LLVM_SDIR}/llvm"

ninja distribution
ninja install-distribution

echo "LLVM stage2 build completed successfully!"
