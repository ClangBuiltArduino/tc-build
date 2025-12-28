#!/bin/bash
# Copyright (C) 2025 ClangBuiltArduino
# SPDX-License-Identifier: Apache-2.0
#
# Simple build script for local toolchain builds.
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    cat <<EOF
${CYAN}ClangBuiltArduino Toolchain Builder${NC}

Usage: ./build.sh <target> [options]

Targets:
  deps            Build zlib and zstd dependencies
  llvm-stage1     Build LLVM bootstrap compiler
  llvm-stage2     Build final LLVM toolchain
  llvm            Build complete LLVM (deps + stage1 + stage2 + extras)
  llvm-gold       Build LLVMgold.so plugin
  sysroot-avr     Build AVR sysroot (avr-libc + libgcc)
  sysroot-arm     Build ARM sysroot (newlib + libgcc)
  bfd             Build BFD linker for AVR
  clean           Remove build artifacts

Options:
  --help, -h      Show this help

Examples:
  ./build.sh deps           # Build dependencies first
  ./build.sh llvm-stage1    # Then bootstrap compiler
  ./build.sh llvm-stage2    # Then final toolchain
  ./build.sh llvm           # Or just build everything at once
  ./build.sh sysroot-avr    # Build AVR sysroot separately

EOF
}

check_deps() {
    local missing=0
    echo -e "${CYAN}Checking build dependencies...${NC}"

    for cmd in clang clang++ lld cmake ninja make wget bsdtar; do
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "  ${RED}✗${NC} $cmd"
            missing=1
        else
            echo -e "  ${GREEN}✓${NC} $cmd"
        fi
    done

    if [[ $missing -eq 1 ]]; then
        echo -e "\n${RED}Missing required tools. Install them and try again.${NC}"
        exit 1
    fi# For CI builds, use the Dockerfiles in dockerfiles/
    echo ""
}

run_script() {
    local script="$1"
    shift

    if [[ ! -f $script ]]; then
        echo -e "${RED}Script not found: $script${NC}"
        exit 1
    fi

    echo -e "${CYAN}Running: $script${NC}"
    bash "$script" "$@"
}

target="${1:-}"

case "$target" in
    deps)
        check_deps
        run_script common/build-deps.sh
        ;;
    llvm-stage1)
        check_deps
        run_script llvm/build-llvm-stage1.sh
        ;;
    llvm-stage2)
        check_deps
        run_script llvm/build-llvm-stage2.sh
        ;;
    llvm-gold)
        check_deps
        run_script llvm/build-llvm-gold.sh
        ;;
    llvm)
        check_deps
        echo -e "${CYAN}=== Building complete LLVM toolchain ===${NC}\n"
        run_script common/build-deps.sh
        echo ""
        run_script llvm/build-llvm-stage1.sh
        echo ""
        run_script llvm/build-llvm-stage2.sh
        echo ""
        run_script llvm/build-llvm-gold.sh
        echo ""
        run_script llvm/build-extra.sh
        echo -e "\n${GREEN}=== LLVM toolchain build complete ===${NC}"
        echo -e "Output: ${SCRIPT_DIR}/install/install/"
        ;;
    sysroot-avr)
        check_deps
        run_script sysroot/build-avr-sysroot.sh
        echo -e "\n${GREEN}=== avr sysroot build complete ===${NC}"
        echo -e "Output: ${SCRIPT_DIR}/install/install/"
        ;;
    sysroot-arm)
        check_deps
        run_script sysroot/build-arm-sysroot.sh
        echo -e "\n${GREEN}=== arm sysroot build complete ===${NC}"
        echo -e "Output: ${SCRIPT_DIR}/install/install/"
        ;;
    bfd)
        check_deps
        if [[ -z ${2:-} ]]; then
            echo -e "${YELLOW}Usage: ./build.sh bfd --target=avr${NC}"
            exit 1
        fi
        run_script binutils/build-bfd.sh "$2"
        ;;
    clean)
        echo -e "${CYAN}Cleaning build artifacts...${NC}"
        rm -rf build/ source/
        echo -e "${GREEN}Clean complete.${NC}"
        ;;
    --help | -h | "")
        usage
        ;;
    *)
        echo -e "${RED}Unknown target: $target${NC}\n"
        usage
        exit 1
        ;;
esac
