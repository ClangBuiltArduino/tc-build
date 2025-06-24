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

# Prepare env
prep_env

# Get sources
cd "${SOURCE_DIR}"
get_tar "https://github.com/ClangBuiltArduino/avr-libc/archive/refs/heads/${AVR_LIBC_VER}.tar.gz" "avr-libc-${AVR_LIBC_VER}.tar.gz"
AVR_LIBC_SDIR="${SOURCE_DIR}/avr-libc-${AVR_LIBC_VER}"
get_tar "https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VER}/gcc-${GCC_VER}.tar.xz" "gcc-${GCC_VER}.tar.xz"
GCC_SDIR="${SOURCE_DIR}/gcc-${GCC_VER}"

# Build avr-libc
cd "${AVR_LIBC_SDIR}" && ./bootstrap
init_build_dir "${BUILD_DIR}/libc"
export CFLAGS_FOR_TARGET='-Os -ffunction-sections -fdata-sections'
export CXXFLAGS_FOR_TARGET='-Os -ffunction-sections -fdata-sections'
"${AVR_LIBC_SDIR}"/configure \
    --host=avr \
    --prefix="${INSTALL_DIR}/avr-sysroot" \
    --disable-doc \
    --disable-html-doc \
    --disable-man-doc \
    --disable-pdf-doc \
    --disable-versioned-doc \
    --enable-silent-rules

make -j"$(nproc --all)"
make install

# Build libgcc
cd "${GCC_SDIR}" && ./contrib/download_prerequisites # Download prerequisites
init_build_dir "${BUILD_DIR}/libgcc"
export CFLAGS_FOR_TARGET='-Os -ffunction-sections -fdata-sections'
export CXXFLAGS_FOR_TARGET='-Os -ffunction-sections -fdata-sections'
"${GCC_SDIR}"/configure \
    --target=avr \
    --prefix="${INSTALL_DIR}/avr-sysroot" \
    --disable-__cxa_atexit \
    --disable-doc \
    --disable-install-libiberty \
    --disable-libada \
    --disable-libssp \
    --disable-libssp \
    --disable-libstdcxx-pch \
    --disable-libunwind-exceptions \
    --disable-nls \
    --disable-shared \
    --disable-werror \
    --enable-languages=c,c++ \
    --enable-static \
    --without-headers

make all-target-libgcc -j"$(nproc --all)"
make install-target-libgcc -j"$(nproc --all)"

# Remove things that we dont need.
rm -rf "${INSTALL_DIR}/avr-sysroot/share"
rm -rf "${INSTALL_DIR}/avr-sysroot/bin"
