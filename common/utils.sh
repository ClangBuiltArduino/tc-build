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

CURR_DIR=$(pwd)

# Set versions
export AVR_LIBC_VER="2.2.1-clang"
export BINUTILS_VERSION="2.44"
export GCC_VER="14.2.0"
export NEWLIB_VER="4.5.0.20241231"
export LLVM_VERSION="20.1.0-rc2"

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
