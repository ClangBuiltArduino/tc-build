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

# https://wiki.musl-libc.org/functional-differences-from-glibc.html#Thread-stack-size
COMMON_LDFLAGS+=("-Wl,-z,stack-size=8388608")

# Prepare environment
prep_env

# Get sources
cd "${SOURCE_DIR}"
get_tar "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/llvm-project-${LLVM_VERSION}.src.tar.xz" "llvm-project-${LLVM_VERSION}.tar.xz"
LLVM_SDIR="${SOURCE_DIR}/llvm-project-${LLVM_VERSION}"

# Build stage1
init_build_dir "${BUILD_DIR}/stage1"
cmake -G "Ninja" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}/stage1" \
    -DLLVM_TARGETS_TO_BUILD="X86" \
    -DLLVM_CCACHE_BUILD=ON \
    -DLLVM_ENABLE_BINDINGS=OFF \
    -DLLVM_ENABLE_OCAMLDOC=OFF \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx;libcxxabi;libunwind" \
    -DLLVM_ENABLE_TERMINFO=OFF \
    -DLLVM_ENABLE_ZLIB=FORCE_ON \
    -DLLVM_ENABLE_ZSTD=FORCE_ON \
    -DLLVM_USE_STATIC_ZSTD=ON \
    -DZLIB_INCLUDE_DIR="${INSTALL_DIR}/zlib/include" \
    -DZLIB_LIBRARY="${INSTALL_DIR}/zlib/lib/libz.a" \
    -Dzstd_INCLUDE_DIR="${INSTALL_DIR}/zstd/include" \
    -Dzstd_LIBRARY="${INSTALL_DIR}/zstd/lib/libzstd.a" \
    -DLLVM_EXTERNAL_CLANG_TOOLS_EXTRA_SOURCE_DIR='' \
    -DLLVM_INCLUDE_DOCS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_TOOL_LLVM_DRIVER_BUILD=ON \
    -DCLANG_DEFAULT_CXX_STDLIB="libc++" \
    -DCLANG_DEFAULT_OBJCOPY="llvm-objcopy" \
    -DCLANG_DEFAULT_RTLIB="compiler-rt" \
    -DCLANG_DEFAULT_UNWINDLIB="libunwind" \
    -DCLANG_ENABLE_ARCMT=OFF \
    -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
    -DCLANG_PLUGIN_SUPPORT=OFF \
    -DCOMPILER_RT_BUILD_BUILTINS=ON \
    -DCOMPILER_RT_BUILD_GWP_ASAN=OFF \
    -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
    -DCOMPILER_RT_BUILD_MEMPROF=OFF \
    -DCOMPILER_RT_BUILD_ORC=OFF \
    -DCOMPILER_RT_BUILD_PROFILE=OFF \
    -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
    -DCOMPILER_RT_BUILD_XRAY=OFF \
    -DCOMPILER_RT_HAS_GCC_S_LIB=OFF \
    -DLIBCXX_CXX_ABI=libcxxabi \
    -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=OFF \
    -DLIBCXX_HAS_ATOMIC_LIB=OFF \
    -DLIBCXX_HAS_GCC_LIB=OFF \
    -DLIBCXX_HAS_GCC_S_LIB=OFF \
    -DLIBCXX_HAS_MUSL_LIBC=ON \
    -DLIBCXX_INCLUDE_BENCHMARKS=OFF \
    -DLIBCXX_INCLUDE_DOCS=OFF \
    -DLIBCXX_INCLUDE_TESTS=OFF \
    -DLIBCXX_USE_COMPILER_RT=ON \
    -DLIBCXXABI_ENABLE_STATIC_UNWINDER=ON \
    -DLIBCXXABI_INCLUDE_TESTS=OFF \
    -DLIBCXXABI_USE_COMPILER_RT=ON \
    -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
    -DLIBUNWIND_INCLUDE_DOCS=OFF \
    -DLIBUNWIND_INCLUDE_TESTS=OFF \
    -DLIBUNWIND_INSTALL_HEADERS=ON \
    -DLIBUNWIND_USE_COMPILER_RT=ON \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_LINKER=lld \
    -DLLVM_USE_LINKER=lld \
    -DCMAKE_C_FLAGS="${COMMON_FLAGS[*]}" \
    -DCMAKE_CXX_FLAGS="${COMMON_FLAGS[*]}" \
    -DCMAKE_EXE_LINKER_FLAGS="${COMMON_LDFLAGS[*]}" \
    -DCMAKE_SHARED_LINKER_FLAGS="${COMMON_LDFLAGS[*]}" \
    "${LLVM_SDIR}/llvm"

ninja -j"$(nproc --all)"
rm -rf "${INSTALL_DIR}/stage1"
ninja install

# Create symlinks for libc++ and friends
cd "$INSTALL_DIR/stage1/lib"
for library in libc++abi.so.1 libc++.a libc++abi.a libc++.so.1 libunwind.so.1 libunwind.a; do
    ln -sv "${INSTALL_DIR}/stage1/lib/$(uname -m)-unknown-linux-gnu/${library}" .
done

echo "LLVM stage1 build completed successfully!"
