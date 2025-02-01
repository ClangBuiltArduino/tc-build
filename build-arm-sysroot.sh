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

# Prepare env
prep_env

# Get sources
cd "${SOURCE_DIR}"
get_tar "ftp://sourceware.org/pub/newlib/newlib-${NEWLIB_VER}.tar.gz" "newlib-${NEWLIB_VER}.tar.gz"
NEWLIB_SDIR="${SOURCE_DIR}/newlib-${NEWLIB_VER}"
get_tar "https://ftp.gnu.org/gnu/gcc/gcc-14.2.0/gcc-${GCC_VER}.tar.xz" "gcc-${GCC_VER}.tar.xz"
GCC_SDIR="${SOURCE_DIR}/gcc-${GCC_VER}"

# Build newlib-libc
init_build_dir "${BUILD_DIR}/libc"
export CFLAGS_FOR_TARGET='-Os -ffunction-sections -fdata-sections'
export CXXFLAGS_FOR_TARGET='-Os -ffunction-sections -fdata-sections'
"${NEWLIB_SDIR}"/configure \
    --target=arm-none-eabi \
    --prefix="${INSTALL_DIR}/arm-sysroot" \
    --disable-doc \
    --disable-html-doc \
    --disable-man-doc \
    --disable-pdf-doc \
    --disable-versioned-doc \
    --enable-newlib-io-long-long \
    --enable-silent-rules \
    --disable-newlib-supplied-syscalls \
    --disable-nls \
    --enable-newlib-io-c99-formats \
    --enable-newlib-register-fini \
    --enable-newlib-retargetable-locking

make -j"$(nproc --all)"
make install

# Build libgcc
init_build_dir "${BUILD_DIR}/libgcc"
export CFLAGS_FOR_TARGET='-Os -ffunction-sections -fdata-sections'
export CXXFLAGS_FOR_TARGET='-Os -ffunction-sections -fdata-sections'
"${GCC_SDIR}"/configure \
    --target=arm-none-eabi \
    --prefix="${INSTALL_DIR}/arm-sysroot" \
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
rm -rf "${INSTALL_DIR}/arm-sysroot/share"
