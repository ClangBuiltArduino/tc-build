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

# Set vars
PKG_DATE="$(date "+%d%m%Y")"

CROSS_PKG=0
PKG_USE_GZ=0
PKG_USE_ZSTD=0
PKG_USE_ZIP=0
for arg in "$@"; do
    case "${arg}" in
        "--gz-tar")
            PKG_USE_GZ=1
            ;;
        "--zstd-tar")
            PKG_USE_ZSTD=1
            ;;
        "--zip")
            PKG_USE_ZIP=1
            ;;
        "--llvm-tc")
            DIR_NAME="cba-llvm-${LLVM_VERSION}-${PKG_DATE}"
            PKG_TAG="llvm-${LLVM_VERSION}-${PKG_DATE}"
            ;;
        "--llvm-gold")
            DIR_NAME="cba-llvm-gold-${LLVM_VERSION}-${PKG_DATE}"
            PKG_TAG="llvmgold-${LLVM_VERSION}-${PKG_DATE}"
            ;;
        "--bfd")
            DIR_NAME="bfd-avr-${BINUTILS_VERSION}-${PKG_DATE}"
            PKG_TAG="bfd-${BINUTILS_VERSION}-${PKG_DATE}"
            ;;
        "--sysroot"*)
            PKG_SYSROOT_TARGET="${arg#*--sysroot}"
            PKG_SYSROOT_TARGET=${PKG_SYSROOT_TARGET:1}
            DIR_NAME="cba-sysroot-${PKG_SYSROOT_TARGET}-${PKG_DATE}"
            PKG_TAG="sysroot-${PKG_SYSROOT_TARGET}-${PKG_DATE}"
            CORSS_PKG=1
            ;;
        "--pkg-arch"*)
            PKG_ARCH="${arg#*--pkg-arch}"
            PKG_ARCH=${PKG_ARCH:1}
            ;;
        "--pkg-os"*)
            PKG_OS="${arg#*--pkg-os}"
            PKG_OS=${PKG_OS:1}
            ;;
        *)
            echo "Invalid argument passed: ${arg}"
            exit 1
            ;;
    esac
done

if [[ "$CROSS_PKG" -eq 1 ]]; then
    FILE_NAME="${DIR_NAME}-any"
else
    FILE_NAME="${DIR_NAME}-${PKG_ARCH}-${PKG_OS}"
fi

# Compress and create archives
cd "${INSTALL_DIR}"
mv "install" "${DIR_NAME}"

# Create zstd archive
if [[ "$PKG_USE_ZSTD" -eq 1 ]]; then
    tar -I "zstd -T$(nproc --all) -19" -cf "${FILE_NAME}.tar.zst" "${DIR_NAME}"
fi

# Create gzip archive
if [[ "$PKG_USE_ZSTD" -eq 1 ]]; then
    tar -I "gzip --best" -cf "${FILE_NAME}.tar.gz" "${DIR_NAME}"
fi

# Create zip archive
if [[ "$PKG_USE_ZIP" -eq 1 ]]; then
    zip -r9 "${FILE_NAME}.zip" "${DIR_NAME}"
fi

git clone "https://github.com/ClangBuiltArduino/tc-build.git" "tc-build"
cd "tc-build"

PKG_REL_TITLE="$(echo "$PKG_TAG" | tr '-' ' ')"

for archive in "${INSTALL_DIR}/${FILE_NAME}".*; do
    if gh release view "${PKG_TAG}"; then
        echo "Uploading build archive on tag '${PKG_TAG}'..."
        gh release upload --clobber "${PKG_TAG}" "${archive}" && {
            echo "Uploaded: ${archive}"
        }
    else
        echo "Creating release with tag '${PKG_TAG}'..."
        gh release create "${PKG_TAG}" "${archive}" -t "${PKG_REL_TITLE}" -n "" && {
            echo "Version ${PKG_TAG} released!" && {
                echo "Uploaded: ${archive}"
            }
        }
    fi
done
