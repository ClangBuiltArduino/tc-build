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
HOST="$1"
DIR_NAME="bfd-avr-${BINUTILS_VERSION}-${TDATE}"

# Adjust FILE_NAME based on HOST
if [ "$HOST" = "windows" ]; then
    FILE_NAME="${DIR_NAME}-${HOST}"
else
    FILE_NAME="${DIR_NAME}-linux-${HOST}"
fi

# Compress and create archives
cd "${INSTALL_DIR}"
mv "install" "${DIR_NAME}"

# Create zstd archive
tar -I "zstd -k -T$(nproc --all) -19" -cf "${FILE_NAME}.tar.zst" "${DIR_NAME}"
# Create gzip archive
tar -I "gzip -k --best" -cf "${FILE_NAME}.tar.gz" "${DIR_NAME}"
# Create zip archive (only for windows)
if [ "$HOST" = "windows" ]; then
    zip -r9 "${FILE_NAME}.zip" "${DIR_NAME}"
fi

git clone "https://github.com/ClangBuiltArduino/tc-build.git" "tc-build"
cd "tc-build"

ls "${INSTALL_DIR}"

for archive in "${INSTALL_DIR}/${FILE_NAME}".*; do
    if gh release view "bfd-${BINUTILS_VERSION}-${TDATE}"; then
        echo "Uploading build archive on tag 'bfd-${BINUTILS_VERSION}-${TDATE}'..."
        gh release upload --clobber "bfd-${BINUTILS_VERSION}-${TDATE}" "${archive}" && {
            echo "Uploaded: ${archive}"
        }
    else
        echo "Creating release with tag 'bfd-${BINUTILS_VERSION}-${TDATE}'..."
        gh release create "bfd-${BINUTILS_VERSION}-${TDATE}" "${archive}" -t "bfd ${BINUTILS_VERSION} ${TDATE}" -n "" && {
            echo "Version bfd-${BINUTILS_VERSION}-${TDATE} released!" && {
                echo "Uploaded: ${archive}"
            }
        }
    fi
done
