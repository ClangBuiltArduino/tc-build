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

COMMON_FLAGS+=("-O2" "-fPIC")

if is_musl; then
    # https://wiki.musl-libc.org/functional-differences-from-glibc.html#Thread-stack-size
    COMMON_LDFLAGS+=("-Wl,-z,stack-size=1048576") # 1MB stack size
fi

# Versions come from utils.sh (via versions.conf)

# Cross builds get the cmake toolchain file so try_compile checks work; native
# builds keep using the host compiler directly.
TOOLCHAIN_ARGS=()
ZSTD_CROSS_ARGS=()
if [[ -n ${CROSS_TOOLCHAIN_FILE:-} ]]; then
    TOOLCHAIN_ARGS+=(-DCMAKE_TOOLCHAIN_FILE="${CROSS_TOOLCHAIN_FILE}")
    # zstd's contrib/gen_html is a build-time host tool; cross-compiling it
    # produces a target binary that cmake then tries to run. We only need
    # libzstd.a, so skip contrib/programs entirely in cross mode.
    ZSTD_CROSS_ARGS+=(-DZSTD_BUILD_CONTRIB=OFF -DZSTD_BUILD_PROGRAMS=OFF)
fi

# Prepare environment
prep_env

# Get sources
cd "${SOURCE_DIR}"
get_tar "${ZLIB_URL}" "zlib-${ZLIB_VERSION}.tar.gz"
ZLIB_SDIR="${SOURCE_DIR}/zlib-${ZLIB_VERSION}"

get_tar "${ZSTD_URL}" "zstd-${ZSTD_VERSION}.tar.gz"
ZSTD_SDIR="${SOURCE_DIR}/zstd-${ZSTD_VERSION}"

# Build zlib
init_build_dir "${BUILD_DIR}/zlib"
cmake -G Ninja \
    "${TOOLCHAIN_ARGS[@]}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}/zlib" \
    -DCMAKE_C_COMPILER="${CC:-clang}" \
    -DCMAKE_CXX_COMPILER="${CXX:-clang++}" \
    -DCMAKE_LINKER="${LD:-lld}" \
    -DCMAKE_C_FLAGS="${COMMON_FLAGS[*]}" \
    -DCMAKE_CXX_FLAGS="${COMMON_FLAGS[*]}" \
    -DCMAKE_EXE_LINKER_FLAGS="${COMMON_LDFLAGS[*]}" \
    -DZLIB_COMPAT=ON \
    -DWITH_GTEST=OFF \
    "${ZLIB_SDIR}"

ninja -j"$(ncpus)"
rm -rf "${INSTALL_DIR}/zlib"
ninja install

# Build zstd
init_build_dir "${BUILD_DIR}/zstd"
cmake -G Ninja \
    "${TOOLCHAIN_ARGS[@]}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}/zstd" \
    -DCMAKE_C_COMPILER="${CC:-clang}" \
    -DCMAKE_CXX_COMPILER="${CXX:-clang++}" \
    -DCMAKE_LINKER="${LD:-lld}" \
    -DCMAKE_C_FLAGS="${COMMON_FLAGS[*]}" \
    -DCMAKE_CXX_FLAGS="${COMMON_FLAGS[*]}" \
    -DCMAKE_EXE_LINKER_FLAGS="${COMMON_LDFLAGS[*]}" \
  	-DZSTD_BUILD_TESTS=OFF \
    -DZSTD_BUILD_CONTRIB=ON \
    -DZSTD_BUILD_SHARED=OFF \
    -DZSTD_BUILD_STATIC=ON \
    -DZSTD_MULTITHREAD_SUPPORT=ON \
    "${ZSTD_CROSS_ARGS[@]}" \
    "${ZSTD_SDIR}/build/cmake"

ninja -j"$(ncpus)"
rm -rf "${INSTALL_DIR}/zstd"
ninja install
