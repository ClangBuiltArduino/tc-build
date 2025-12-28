# ClangBuiltArduino Toolchain

Build scripts for a slim LLVM-based toolchain targeting AVR and ARM (Arduino).

## Build locally
```bash
./build.sh llvm          # Build complete LLVM toolchain
./build.sh sysroot-avr   # Build AVR sysroot
./build.sh --help        # See all options
```

## Project Structure
```
tc-build/
├── build.sh           # Local build entry point
├── versions.conf      # All versions and URLs for source tarballs
├── common/            # Shared scripts
│   ├── utils.sh       # Common functions
│   ├── build-deps.sh  # Build dependencies
│   └── push-build.sh  # Package and release
├── llvm/              # LLVM build scripts
├── sysroot/           # Sysroot build scripts
├── binutils/          # BFD linker build
└── dockerfiles/       # Docker builds for CI
```

## Toolchain Components

| Component        | Selection                     |
|------------------|------------------------------ |
| Compiler         | Clang/Clang++                 |
| Binary Tools     | LLVM Tools                    |
| Linker           | LLD (default), BFD (AVR only) |
| Libc Library     | avr-libc (AVR), newlib (ARM)  |
| Runtime Library  | libgcc                        |

### AVR Linker Support
Due to incomplete AVR linker script support in LLD, the toolchain includes the GNU BFD linker as a workaround. Once LLD fully supports AVR linker scripts, BFD will be removed.

### Arduino Compatibility
A [clang-wrapper](https://github.com/ClangBuiltArduino/clang-wrapper) is included mprove compatibility with the Arduino build system by handling specific flag adjustments.

## Distribution and Packaging

1. **LLVM Toolchain** - Statically linked Clang/LLVM binaries
2. **Sysroot** - Target libraries (avr-libc/newlib + libgcc)
3. **BFD Linker** - Optional GNU linker for AVR

## License

Apache-2.0 - See [LICENSE](LICENSE)

