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
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}"/../common/utils.sh &> /dev/null || source utils.sh # Include basic common utilities
set -euo pipefail

# https://wiki.musl-libc.org/functional-differences-from-glibc.html#Thread-stack-size
ldd --version 2>&1 | grep -q musl && COMMON_LDFLAGS+=("-Wl,-z,stack-size=1048576")

COMMON_FLAGS+=(
    "-Os"   # We dont really care about performance of this one program, Lets just save some space.
    "-flto" # Better DCE.
    "-fPIC" # Since its dynamically linked.
    "-I${INSTALL_DIR}/zstd/include"
)

# Use our static zstd lib to avoid dependency on zstd.
COMMON_LDFLAGS=("-L$INSTALL_DIR/zstd/lib" "-lzstd" "-Bstatic")

# Prep env
prep_env

# Get configuration
TARGET=""
BUILD_LD_SCRIPTS=0
PACK=0
for arg in "$@"; do
    case "${arg}" in
        "--target"*)
            TARGET="${arg#*--target}"
            TARGET="${TARGET:1}"
            ;;
        "--linker-scripts")
            BUILD_LD_SCRIPTS=1
            ;;
        "--pack-install")
            PACK=1
            ;;
    esac
done

if [[ -z $TARGET ]]; then
    echo "Error: --target option is required." >&2
    exit 1
fi

# Get source
cd "${SOURCE_DIR}"
get_tar "https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz" "binutils-${BINUTILS_VERSION}.tar.xz"
BINUTILS_SDIR="${SOURCE_DIR}/binutils-${BINUTILS_VERSION}"

# Build bfd linker
init_build_dir "${BUILD_DIR}/binutils"
export CFLAGS="${COMMON_FLAGS[*]}"
export CXXFLAGS="${COMMON_FLAGS[*]}"
export LDFLAGS="${COMMON_LDFLAGS[*]}"
"${BINUTILS_SDIR}"/configure \
    --prefix="${INSTALL_DIR}/bfd-${TARGET}" \
    --htmldir="${INSTALL_DIR}/deleteme" \
    --infodir="${INSTALL_DIR}/deleteme" \
    --mandir="${INSTALL_DIR}/deleteme" \
    --pdfdir="${INSTALL_DIR}/deleteme" \
    --with-bugurl=https://github.com/ClangBuiltArduino/issue-tracker/issues \
    --disable-binutils \
    --disable-compressed-debug-sections \
    --disable-dwp \
    --disable-gas \
    --disable-gdb \
    --disable-gdbserver \
    --disable-gold \
    --disable-gprof \
    --disable-multilib \
    --disable-werror \
    --enable-deterministic-archives \
    --enable-ld=default \
    --enable-lto \
    --enable-plugins \
    --enable-threads \
    --target="${TARGET}" \
    --with-static-standard-libraries

make configure-host
make LDFLAGS="${COMMON_LDFLAGS[*]}" -j"$(nproc --all)"
make install

# Remove unwanted docs
rm -rf "${INSTALL_DIR}/deleteme"
rm -rf "${INSTALL_DIR}/bfd-${TARGET}/share"
if [[ $BUILD_LD_SCRIPTS -eq 1 ]]; then
    rm -rf "${INSTALL_DIR}/bfd-${TARGET}/bin"
    rm -rf "${INSTALL_DIR}/bfd-${TARGET}/lib"
    rm -rf "${INSTALL_DIR}/bfd-${TARGET}/${TARGET}/bin"
else
    rm -rf "${INSTALL_DIR}/bfd-${TARGET}/${TARGET}/lib"
fi

if [[ $PACK -eq 1 ]]; then
    mkdir -p "${INSTALL_DIR}/install/"
    cp -r "${INSTALL_DIR}/bfd-${TARGET}"/* "${INSTALL_DIR}/install/"
fi