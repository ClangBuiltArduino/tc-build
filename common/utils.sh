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
set -euo pipefail

# Find and source versions.conf
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
if [[ -f "${SCRIPT_DIR}/../versions.conf" ]]; then
    source "${SCRIPT_DIR}/../versions.conf"
elif [[ -f "/versions.conf" ]]; then
    source "/versions.conf" # Docker context
elif [[ -f "./versions.conf" ]]; then
    source "./versions.conf"
fi

CURR_DIR=$(pwd)

# Export versions for compatibility with existing scripts
export AVR_LIBC_VER="${AVR_LIBC_VERSION}"
export AVR_LIBC_URL="${AVR_LIBC_URL}"
export BINUTILS_VERSION="${BINUTILS_VERSION}"
export GCC_VER="${GCC_VERSION}"
export GCC_URL="${GCC_URL}"
export NEWLIB_VER="${NEWLIB_VERSION}"
export LLVM_VERSION="${LLVM_VERSION}"
export ZLIB_VERSION="${ZLIB_VERSION}"
export ZSTD_VERSION="${ZSTD_VERSION}"

# Configuration
SOURCE_DIR="${CURR_DIR}/source"
BUILD_DIR="${CURR_DIR}/build"
INSTALL_DIR="${CURR_DIR}/install"

export COMMON_FLAGS=("-ffunction-sections"
    "-fdata-sections"
    "-pipe")
export COMMON_LDFLAGS=("-Wl,--gc-sections"
    "-Wl,--strip-debug")

# Helpful utility functions
prep_env() {
    echo "Creating dirs..."
    for dir in "$SOURCE_DIR" "$BUILD_DIR" "$INSTALL_DIR"; do
        [ -d "$dir" ] || mkdir -p "$dir"
    done
}

get_tar() {
    echo "Checking for existing file: $2"

    # Get the base filename by stripping common multi-extension suffixes
    extract_dir="${2%.tar.*}" # Removes .tar.gz, .tar.xz, .tar.bz2, etc.

    if [ -d "$extract_dir" ]; then
        echo "Extraction directory '$extract_dir' already exists. Skipping extraction."
    else
        if [ -f "$2" ]; then
            echo "Using existing file: $2"
        else
            echo "Downloading from $1 as $2 ..."
            wget -O"$2" "$1"
        fi
        echo "Extracting $2 into $extract_dir ..."
        mkdir "$extract_dir"
        bsdtar -xf "$2" -C "$extract_dir" --strip-components=1 # Removes the top-level directory
        rm -f "$2"
    fi
}

init_build_dir() {
    rm -rf "$1" && mkdir "$1" && cd "$1"
}

strip_bins() {
    for f in $(find "$1" -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
        f="${f::-1}"
        echo "Stripping: ${f}"
        "$2" "${f}"
    done
}

get_patch() {
    echo "Applying patch: $1"
    curl -sL "$1" | patch -Np1
}

apply_llvm_patches() {
    for patch in "${LLVM_PATCHES[@]}"; do
        get_patch "$patch"
    done
}
