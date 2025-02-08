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
TDATE="$(date "+%d%m%Y")"
TARGET="$1"
DIR_NAME="cba-sysroot-${TARGET}-${TDATE}"
FILE_NAME="${DIR_NAME}"

# Compress and create archives
cd "${INSTALL_DIR}"
mv "install" "${DIR_NAME}"

# Create zstd archive
tar -I "zstd -T$(nproc --all) -19" -cf "${FILE_NAME}.tar.zst" "${DIR_NAME}"
# Create gzip archive
tar -I "gzip --best" -cf "${FILE_NAME}.tar.gz" "${DIR_NAME}"
# Create zip archive
zip -r9 "${FILE_NAME}.zip" "${DIR_NAME}"

git clone "https://github.com/ClangBuiltArduino/tc-build.git" "tc-build"
cd "tc-build"

for archive in "${INSTALL_DIR}/${FILE_NAME}".*; do
    if gh release view "sysroot-${TARGET}-${TDATE}"; then
        echo "Uploading build archive on tag 'sysroot-${TARGET}-${TDATE}'..."
        gh release upload --clobber "sysroot-${TARGET}-${TDATE}" "${archive}" && {
            echo "Uploaded: ${archive}"
        }
    else
        echo "Creating release with tag 'sysroot-${TARGET}-${TDATE}'..."
        gh release create "sysroot-${TARGET}-${TDATE}" "${archive}" -t "${TARGET} sysroot ${TDATE}" -n "" && {
            echo "Version sysroot-${TARGET}-${TDATE} released!" && {
                echo "Uploaded: ${archive}"
            }
        }
    fi
done
