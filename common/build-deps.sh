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
source utils.sh # Include basic common utilities
set -euo pipefail

COMMON_FLAGS+=("-O2" "-fPIC")

if ! getconf GNU_LIBC_VERSION >/dev/null 2>&1; then
    # https://wiki.musl-libc.org/functional-differences-from-glibc.html#Thread-stack-size
    COMMON_LDFLAGS+=("-Wl,-z,stack-size=1048576") # 1MB stack size
fi

# Set versions
ZLIB_VERSION="2.2.4"
ZSTD_VERSION="1.5.7"

# Prepare environment
prep_env

# Get sources
cd "${SOURCE_DIR}"
get_tar "https://github.com/zlib-ng/zlib-ng/archive/refs/tags/${ZLIB_VERSION}.tar.gz" "zlib-${ZLIB_VERSION}.tar.gz"
ZLIB_SDIR="${SOURCE_DIR}/zlib-${ZLIB_VERSION}"

get_tar "https://github.com/facebook/zstd/archive/refs/tags/v${ZSTD_VERSION}.tar.gz" "zstd-${ZLIB_VERSION}.tar.gz"
ZSTD_SDIR="${SOURCE_DIR}/zstd-${ZLIB_VERSION}"

# Build zlib
init_build_dir "${BUILD_DIR}/zlib"
cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}/zlib" \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_LINKER=lld \
    -DCMAKE_C_FLAGS="${COMMON_FLAGS[*]}" \
    -DCMAKE_CXX_FLAGS="${COMMON_FLAGS[*]}" \
    -DCMAKE_EXE_LINKER_FLAGS="${COMMON_LDFLAGS[*]}" \
    -DZLIB_COMPAT=ON \
    -DWITH_GTEST=OFF \
    "${ZLIB_SDIR}"

ninja -j"$(nproc --all)"
rm -rf "${INSTALL_DIR}/zlib"
ninja install

# Build zstd
init_build_dir "${BUILD_DIR}/zstd"
cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}/zstd" \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_LINKER=lld \
    -DCMAKE_C_FLAGS="${COMMON_FLAGS[*]}" \
    -DCMAKE_CXX_FLAGS="${COMMON_FLAGS[*]}" \
    -DCMAKE_EXE_LINKER_FLAGS="${COMMON_LDFLAGS[*]}" \
    -DZSTD_BUILD_TESTS=OFF \
    -DZSTD_BUILD_CONTRIB=ON \
    -DZSTD_BUILD_SHARED=OFF \
    -DZSTD_BUILD_STATIC=ON \
    -DZSTD_MULTITHREAD_SUPPORT=ON \
    "${ZSTD_SDIR}/build/cmake"

ninja -j"$(nproc --all)"
rm -rf "${INSTALL_DIR}/zstd"
ninja install
