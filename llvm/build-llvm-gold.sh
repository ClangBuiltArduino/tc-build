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

# Set path for using libs from stage 1
COMMON_LDFLAGS+=(
    "-L${INSTALL_DIR}/stage1/lib"
    "-L${INSTALL_DIR}/stage1/lib/x86_64-unknown-linux-gnu/"
)

# Set flags for using LLVM stdlibs.
COMMON_LDFLAGS+=(
    "-Wl,--as-needed"
    "-Wl,-Bstatic"
    "-stdlib=libc++"
    "--unwindlib=libunwind"
    "-lc++"
    "-lc++abi"
)

# Detect if host has musl or glibc for configuring
if ldd --version 2>&1 | grep -qi musl; then
    # https://wiki.musl-libc.org/functional-differences-from-glibc.html#Thread-stack-size
    COMMON_LDFLAGS+=("-Wl,-z,stack-size=8388608")
fi

# Prepare environment
prep_env

# Get sources
cd "${SOURCE_DIR}"
get_tar "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/llvm-project-${LLVM_VERSION}.src.tar.xz" "llvm-project-${LLVM_VERSION}.tar.xz"
LLVM_SDIR="${SOURCE_DIR}/llvm-project-${LLVM_VERSION}"
get_tar "https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz" "binutils-${BINUTILS_VERSION}.tar.xz"
BINUTILS_SDIR="${SOURCE_DIR}/binutils-${BINUTILS_VERSION}"

# Use tools exclusively from bootstrap build if possible.
export PATH="$INSTALL_DIR/stage1/bin:$PATH"
export LD_LIBRARY_PATH="$INSTALL_DIR/stage1/lib/x86_64-unknown-linux-gnu:$INSTALL_DIR/stage1/lib"

# Build stage2
init_build_dir "${BUILD_DIR}/llvmgold"
cmake -G "Ninja" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_TARGETS_TO_BUILD="AVR;ARM" \
    -DLLVM_ENABLE_PROJECTS="llvm" \
    -DLLVM_DISTRIBUTION_COMPONENTS="LLVMgold" \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}/install" \
    -DLLVM_BINUTILS_INCDIR="${BINUTILS_SDIR}/include" \
    -DLLVM_BUILD_SHARED_LIBS=OFF \
    -DLLVM_BUILD_TOOLS=OFF \
    -DLLVM_BUILD_UTILS=OFF \
    -DLLVM_CCACHE_BUILD=ON \
    -DLLVM_ENABLE_BACKTRACES=OFF \
    -DLLVM_ENABLE_BINDINGS=OFF \
    -DLLVM_ENABLE_LIBCXX=ON \
    -DLLVM_ENABLE_LIBXML2=OFF \
    -DLLVM_ENABLE_LLD=ON \
    -DLLVM_ENABLE_LTO=THIN \
    -DLLVM_ENABLE_OCAMLDOC=OFF \
    -DLLVM_ENABLE_PIC=ON \
    -DLLVM_ENABLE_ZLIB=ON \
    -DLLVM_ENABLE_ZSTD=ON \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_INCLUDE_DOCS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_UTILS=OFF \
    -DLLVM_LINK_LLVM_DYLIB=OFF \
    -DLLVM_STATIC_LINK_CXX_STDLIB=ON \
    -DLLVM_TOOL_BUGPOINT_BUILD=OFF \
    -DLLVM_TOOL_BUGPOINT_PASSES_BUILD=OFF \
    -DLLVM_TOOL_DSYMUTIL_BUILD=OFF \
    -DLLVM_TOOL_DXIL_DIS_BUILD=OFF \
    -DLLVM_TOOL_LLC_BUILD=OFF \
    -DLLVM_TOOL_LLI_BUILD=OFF \
    -DLLVM_TOOL_LLVM_BCANALYZER_BUILD=OFF \
    -DLLVM_TOOL_LLVM_C_TEST_BUILD=OFF \
    -DLLVM_TOOL_LLVM_CAT_BUILD=OFF \
    -DLLVM_TOOL_LLVM_CFI_VERIFY_BUILD=OFF \
    -DLLVM_TOOL_LLVM_CONFIG_BUILD=OFF \
    -DLLVM_TOOL_LLVM_COV_BUILD=OFF \
    -DLLVM_TOOL_LLVM_CVTRES_BUILD=OFF \
    -DLLVM_TOOL_LLVM_CXXDUMP_BUILD=OFF \
    -DLLVM_TOOL_LLVM_CXXFILT_BUILD=OFF \
    -DLLVM_TOOL_LLVM_CXXMAP_BUILD=OFF \
    -DLLVM_TOOL_LLVM_DEBUGINFO_ANALYZER_BUILD=OFF \
    -DLLVM_TOOL_LLVM_DEBUGINFOD_BUILD=OFF \
    -DLLVM_TOOL_LLVM_DEBUGINFOD_BUILD=OFF \
    -DLLVM_TOOL_LLVM_DEBUGINFOD_FIND_BUILD=OFF \
    -DLLVM_TOOL_LLVM_DIFF_BUILD=OFF \
    -DLLVM_TOOL_LLVM_DIS_BUILD=OFF \
    -DLLVM_TOOL_LLVM_DIS_FUZZER_BUILD=OFF \
    -DLLVM_TOOL_LLVM_DLANG_DEMANGLE_FUZZER_BUILD=OFF \
    -DLLVM_TOOL_LLVM_DWARFDUMP_BUILD=OFF \
    -DLLVM_TOOL_LLVM_DWARFUTIL_BUILD=OFF \
    -DLLVM_TOOL_LLVM_DWP_BUILD=OFF \
    -DLLVM_TOOL_LLVM_EXEGESIS_BUILD=OFF \
    -DLLVM_TOOL_LLVM_EXTRACT_BUILD=OFF \
    -DLLVM_TOOL_LLVM_GSYMUTIL_BUILD=OFF \
    -DLLVM_TOOL_LLVM_IFS_BUILD=OFF \
    -DLLVM_TOOL_LLVM_ISEL_FUZZER_BUILD=OFF \
    -DLLVM_TOOL_LLVM_ITANIUM_DEMANGLE_FUZZER_BUILD=OFF \
    -DLLVM_TOOL_LLVM_JITLINK_BUILD=OFF \
    -DLLVM_TOOL_LLVM_JITLISTENER_BUILD=OFF \
    -DLLVM_TOOL_LLVM_LIBTOOL_DARWIN_BUILD=OFF \
    -DLLVM_TOOL_LLVM_LINK_BUILD=OFF \
    -DLLVM_TOOL_LLVM_LIPO_BUILD=OFF \
    -DLLVM_TOOL_LLVM_LTO_BUILD=OFF \
    -DLLVM_TOOL_LLVM_LTO2_BUILD=OFF \
    -DLLVM_TOOL_LLVM_MC_ASSEMBLE_FUZZER_BUILD=OFF \
    -DLLVM_TOOL_LLVM_MC_BUILD=OFF \
    -DLLVM_TOOL_LLVM_MC_DISASSEMBLE_FUZZER_BUILD=OFF \
    -DLLVM_TOOL_LLVM_MCA_BUILD=OFF \
    -DLLVM_TOOL_LLVM_MICROSOFT_DEMANGLE_FUZZER_BUILD=OFF \
    -DLLVM_TOOL_LLVM_ML_BUILD=OFF \
    -DLLVM_TOOL_LLVM_MODEXTRACT_BUILD=OFF \
    -DLLVM_TOOL_LLVM_MT_BUILD=OFF \
    -DLLVM_TOOL_LLVM_OPT_FUZZER_BUILD=OFF \
    -DLLVM_TOOL_LLVM_OPT_REPORT_BUILD=OFF \
    -DLLVM_TOOL_LLVM_PDBUTIL_BUILD=OFF \
    -DLLVM_TOOL_LLVM_PROFDATA_BUILD=OFF \
    -DLLVM_TOOL_LLVM_PROFGEN_BUILD=OFF \
    -DLLVM_TOOL_LLVM_RC_BUILD=OFF \
    -DLLVM_TOOL_LLVM_READTAPI_BUILD=OFF \
    -DLLVM_TOOL_LLVM_REDUCE_BUILD=OFF \
    -DLLVM_TOOL_LLVM_REMARKUTIL_BUILD=OFF \
    -DLLVM_TOOL_LLVM_RTDYLD_BUILD=OFF \
    -DLLVM_TOOL_LLVM_RUST_DEMANGLE_FUZZER_BUILD=OFF \
    -DLLVM_TOOL_LLVM_SHLIB_BUILD=OFF \
    -DLLVM_TOOL_LLVM_SIM_BUILD=OFF \
    -DLLVM_TOOL_LLVM_SPECIAL_CASE_LIST_FUZZER_BUILD=OFF \
    -DLLVM_TOOL_LLVM_SPLIT_BUILD=OFF \
    -DLLVM_TOOL_LLVM_STRESS_BUILD=OFF \
    -DLLVM_TOOL_LLVM_TLI_CHECKER_BUILD=OFF \
    -DLLVM_TOOL_LLVM_UNDNAME_BUILD=OFF \
    -DLLVM_TOOL_LLVM_XRAY_BUILD=OFF \
    -DLLVM_TOOL_LLVM_YAML_NUMERIC_PARSER_FUZZER_BUILD=OFF \
    -DLLVM_TOOL_LLVM_YAML_PARSER_FUZZER_BUILD=OFF \
    -DLLVM_TOOL_LTO_BUILD=OFF \
    -DLLVM_TOOL_OBJ2YAML_BUILD=OFF \
    -DLLVM_TOOL_OPT_BUILD=OFF \
    -DLLVM_TOOL_OPT_VIEWER_BUILD=OFF \
    -DLLVM_TOOL_REDUCE_CHUNK_LIST_BUILD=OFF \
    -DLLVM_TOOL_REMARKS_SHLIB_BUILD=OFF \
    -DLLVM_TOOL_SANCOV_BUILD=OFF \
    -DLLVM_TOOL_SANSTATS_BUILD=OFF \
    -DLLVM_TOOL_SPIRV_TOOLS_BUILD=OFF \
    -DLLVM_TOOL_VERIFY_USELISTORDER_BUILD=OFF \
    -DLLVM_TOOL_VFABI_DEMANGLE_FUZZER_BUILD=OFF \
    -DLLVM_TOOL_XCODE_TOOLCHAIN_BUILD=OFF \
    -DLLVM_TOOL_YAML2OBJ_BUILD=OFF \
    -DLLVM_USE_STATIC_ZSTD=ON \
    -DZLIB_INCLUDE_DIR="${INSTALL_DIR}/zlib/include" \
    -DZLIB_LIBRARY="${INSTALL_DIR}/zlib/lib/libz.a" \
    -Dzstd_INCLUDE_DIR="${INSTALL_DIR}/zstd/include" \
    -Dzstd_LIBRARY="${INSTALL_DIR}/zstd/lib/libzstd.a" \
    -DCMAKE_C_COMPILER="${INSTALL_DIR}/stage1/bin/clang" \
    -DCMAKE_CXX_COMPILER="${INSTALL_DIR}/stage1/bin/clang++" \
    -DCMAKE_C_FLAGS="${COMMON_FLAGS[*]}" \
    -DCMAKE_CXX_FLAGS="${COMMON_FLAGS[*]} -stdlib=libc++" \
    -DCMAKE_EXE_LINKER_FLAGS="-static ${COMMON_LDFLAGS[*]}" \
    -DCMAKE_MODULE_LINKER_FLAGS="${COMMON_LDFLAGS[*]} -Wl,-Bdynamic" \
    -DCMAKE_SHARED_LINKER_FLAGS="${COMMON_LDFLAGS[*]} -Wl,-Bdynamic" \
    -DLLVM_PARALLEL_COMPILE_JOBS="$(nproc --all)" \
    -DLLVM_PARALLEL_LINK_JOBS="$(nproc --all)" \
    "${LLVM_SDIR}/llvm"

ninja distribution
ninja install-distribution

# Strip remaining products
strip_bins "${INSTALL_DIR}/install" "${INSTALL_DIR}/stage1/bin/llvm-strip"

echo "LLVMgold build completed successfully!"
