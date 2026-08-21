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
if [[ $(uname -s) == "Darwin" ]]; then
    export COMMON_LDFLAGS=("-Wl,-dead_strip")
else
    export COMMON_LDFLAGS=("-Wl,--gc-sections"
        "-Wl,--strip-debug")
fi

# Portable CPU count (GNU nproc is Linux-only).
ncpus() {
    nproc --all 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2
}

# True when the current libc is musl (never true on macOS/Windows crosses).
# The loader-path check is definitive; 'ldd --version' output varies across
# busybox/musl versions and architectures.
is_musl() {
    [[ -e "/lib/ld-musl-$(uname -m).so.1" ]] && return 0
    ldd --version 2>&1 | grep -qi musl
}

# Helpful utility functions
prep_env() {
    echo "Creating dirs..."
    for dir in "$SOURCE_DIR" "$BUILD_DIR" "$INSTALL_DIR"; do
        [ -d "$dir" ] || mkdir -p "$dir"
    done
}

get_tar() {
    echo "Checking for existing file: $2" >&2

    # Get the base filename by stripping common multi-extension suffixes
    extract_dir="${2%.tar.*}" # Removes .tar.gz, .tar.xz, .tar.bz2, etc.

    if [ -d "$extract_dir" ]; then
        echo "Extraction directory '$extract_dir' already exists. Skipping extraction." >&2
    else
        if [ -f "$2" ]; then
            echo "Using existing file: $2" >&2
        else
            echo "Downloading from $1 as $2 ..." >&2
            if command -v wget >/dev/null 2>&1; then
                wget -O"$2" "$1"
            else
                curl -fL --retry 3 -o "$2" "$1"
            fi
        fi
        echo "Extracting $2 into $extract_dir ..." >&2
        mkdir "$extract_dir"
        bsdtar -xf "$2" -C "$extract_dir" --strip-components=1 # Removes the top-level directory
        rm -f "$2"
    fi
}

parse_source_args() {
    SOURCE_MODE="release"

    for arg in "$@"; do
        case "$arg" in
        --head-source)
            SOURCE_MODE="head"
            ;;
        esac
    done

    # Compatibility alias for LLVM-only callers
    LLVM_SOURCE_MODE="${SOURCE_MODE}"
}

get_llvm_source() {
    local llvm_sdir="${SOURCE_DIR}/llvm-project-${LLVM_VERSION}"

    if [[ ${LLVM_SOURCE_MODE:-release} == "head" ]]; then
        if [[ -d "${llvm_sdir}/.git" ]]; then
            echo "Updating existing LLVM HEAD checkout..." >&2
            git -C "${llvm_sdir}" fetch --depth 1 origin main >&2
            git -C "${llvm_sdir}" reset --hard FETCH_HEAD >&2
            git -C "${llvm_sdir}" clean -fdx >&2
        else
            if [[ -e ${llvm_sdir} ]]; then
                rm -rf "${llvm_sdir}" >&2
            fi

            echo "Cloning LLVM HEAD checkout..." >&2
            git clone --depth 1 --single-branch --branch main https://github.com/llvm/llvm-project.git "${llvm_sdir}" >&2
        fi
    else
        if [[ -d "${llvm_sdir}/.git" ]]; then
            rm -rf "${llvm_sdir}" >&2
        fi

        get_tar "${LLVM_URL}" "llvm-project-${LLVM_VERSION}.tar.xz" >&2
    fi

    printf '%s\n' "${llvm_sdir}"
}

get_avr_libc_source() {
    local libc_sdir="${SOURCE_DIR}/avr-libc-${AVR_LIBC_VER}"

    if [[ ${SOURCE_MODE:-release} == "head" ]]; then
        if [[ -d "${libc_sdir}/.git" ]]; then
            echo "Updating existing avr-libc HEAD checkout..." >&2
            git -C "${libc_sdir}" fetch --depth 1 origin main >&2
            git -C "${libc_sdir}" reset --hard FETCH_HEAD >&2
            git -C "${libc_sdir}" clean -fdx >&2
        else
            rm -rf "${libc_sdir}" >&2
            echo "Cloning avr-libc HEAD checkout..." >&2
            git clone --depth 1 --single-branch --branch main https://github.com/avrdudes/avr-libc.git "${libc_sdir}" >&2
        fi
    else
        get_tar "${AVR_LIBC_URL}" "avr-libc-${AVR_LIBC_VER}.tar.bz2" >&2
    fi

    printf '%s\n' "${libc_sdir}"
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
    if [[ -z ${LLVM_PATCHES+x} ]]; then
        return
    fi

    for patch in "${LLVM_PATCHES[@]}"; do
        get_patch "$patch"
    done
}
