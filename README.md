# Toolchain build scripts

provides scripts for compiling a slim unified LLVM-based toolchain and sysroot files for AVR and ARM targets.

## Toolchain Configuration

| Component        | Selection                     |
|------------------|------------------------------ |
| Compiler         | Clang/Clang++                 |
| Binary Tools     | LLVM Tools                    |
| Linker           | LLD (default), BFD (AVR only) |
| Libc Library     | avr-libc (AVR), newlibc (ARM) |
| Runtime Library  | libgcc                        |

### AVR Linker Support
Due to incomplete AVR linker script support in LLD, the toolchain also includes the GNU BFD linker as a temporary workaround. This ensures compatibility with existing linker scripts provided by GNU binutils. Once LLD fully supports AVR linker scripts, the BFD linker will be removed.

### Arduino Build System Compatibility
A custom Clang/Clang++ wrapper is included to improve compatibility with the Arduino build system by handling specific flag adjustments. **Know more at [ClangBuiltArduino/clang-wrapper](https://github.com/ClangBuiltArduino/clang-wrapper)**

## Distribution and Packaging
The toolchain is packaged into separate components for better modularity and efficiency:

1. **LLVM Toolchain** (Unified Clang/LLVM binaries, statically linked, requiring no dependencies)
2. **Sysroot** (Target-specific standard libraries and runtime files for AVR/ARM)
3. **BFD linker** (Optional workaround for LLD incompatibilities with AVR, dynamically linked to support loading LLVMgold.so)

This split ensures minimal redundant downloads and allows for easier updates and distribution of the toolchain and its dependencies.

