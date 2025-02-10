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
WORK_DIR="${INSTALL_DIR}/install"
LLVM_BIN_DIR="${INSTALL_DIR}/stage1/bin"
echo "Working dir: ${WORK_DIR}"

# Prep env
prep_env

# Get clang-wrapper source
cd "${SOURCE_DIR}"
git clone "https://github.com/ClangBuiltArduino/clang-wrapper.git" clang-wrapper
cd clang-wrapper
make
make install PREFIX="${INSTALL_DIR}/install"

cd "${CURR_DIR}"

# Strip remaining products
strip_bins "${WORK_DIR}" "${LLVM_BIN_DIR}/llvm-strip"

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
echo "Setting library load paths for portability..."
for bin in $(find "${WORK_DIR}" -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
    # Remove last character from file output (':')
    bin="${bin::-1}"
    echo "${bin}"
    patchelf --set-rpath '$ORIGIN/../lib' "${bin}"
done
