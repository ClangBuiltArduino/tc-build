# Copyright (C) 2026 ClangBuiltArduino
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

# Single-stage cross build of the toolchain for an i686-w64-mingw32 host.
# A two-stage design would need to run the cross-compiled stage1, so the
# LLVM-recommended single-stage cross flow is used instead.

ARG NIGHTLY=0

##############
# Deps build #
##############
FROM debian:bookworm AS deps-cross
WORKDIR /
COPY /versions.conf .
COPY /common/utils.sh .
COPY /common/build-deps.sh .
RUN apt-get update -y
RUN apt-get install cmake ninja-build zstd wget bash gzip tar xz-utils file libarchive-tools build-essential gcc-mingw-w64-i686-posix g++-mingw-w64-i686-posix binutils-mingw-w64-i686 python3 -y
ENV CC=i686-w64-mingw32-gcc-posix
ENV CXX=i686-w64-mingw32-g++-posix
ENV LD=i686-w64-mingw32-ld
RUN bash build-deps.sh

###############
# LLVM cross  #
###############
FROM debian:bookworm AS llvm-cross
ARG NIGHTLY=0
WORKDIR /
COPY --from=deps-cross /install ./install
COPY /versions.conf .
COPY /common/utils.sh .
COPY /llvm/build-llvm-stage2.sh .
COPY /common/cross-mingw-i686.cmake .
RUN apt-get update -y
RUN apt-get install cmake ninja-build zstd wget bash gzip tar xz-utils file libarchive-tools build-essential gcc-mingw-w64-i686-posix g++-mingw-w64-i686-posix binutils-mingw-w64-i686 python3 git -y
# Reuse stage2's cmake flow in single-stage cross mode: CC/CXX point at the
# mingw compilers and the toolchain file describes the Windows host.
ENV CC=i686-w64-mingw32-gcc-posix
ENV CXX=i686-w64-mingw32-g++-posix
ENV CROSS_TOOLCHAIN_FILE=/cross-mingw-i686.cmake
RUN bash build-llvm-stage2.sh $([ "${NIGHTLY:-0}" = "1" ] && echo --head-source)
RUN rm -rf /source && rm -rf /build

###############
# Gold cross  #
###############
FROM debian:bookworm AS gold-cross
ARG NIGHTLY=0
WORKDIR /
COPY --from=deps-cross /install ./install
COPY /versions.conf .
COPY /common/utils.sh .
COPY /llvm/build-llvm-gold.sh .
COPY /common/cross-mingw-i686.cmake .
RUN apt-get update -y
RUN apt-get install cmake ninja-build zstd wget bash gzip tar xz-utils file libarchive-tools build-essential gcc-mingw-w64-i686-posix g++-mingw-w64-i686-posix binutils-mingw-w64-i686 python3 git -y
ENV CC=i686-w64-mingw32-gcc-posix
ENV CXX=i686-w64-mingw32-g++-posix
ENV CROSS_TOOLCHAIN_FILE=/cross-mingw-i686.cmake
RUN bash build-llvm-gold.sh $([ "${NIGHTLY:-0}" = "1" ] && echo --head-source)
RUN rm -rf /source && rm -rf /build

##############
# BFD cross  #
##############
FROM debian:bookworm AS bfd-cross
WORKDIR /
COPY --from=deps-cross /install ./install
COPY /versions.conf .
COPY /common/utils.sh .
COPY /binutils/build-bfd.sh .
RUN apt-get update -y
RUN apt-get install cmake ninja-build zstd wget bash gzip tar xz-utils file libarchive-tools build-essential gcc-mingw-w64-i686-posix g++-mingw-w64-i686-posix binutils-mingw-w64-i686 texinfo libzstd-dev python3 -y
ENV HOST_TRIPLE=i686-w64-mingw32
RUN bash build-bfd.sh --target=avr --pack-install

#############
# Packaging #
#############
FROM debian:bookworm AS packing
ARG NIGHTLY=0
WORKDIR /
COPY --from=llvm-cross /install/install ./pkg/llvm/install
COPY --from=gold-cross /install/install ./pkg/gold/install
COPY --from=bfd-cross /install/install ./pkg/bfd/install
COPY /versions.conf .
COPY /common/utils.sh .
COPY /common/push-build.sh .
RUN apt-get update -y
RUN apt-get install bash zstd coreutils gzip tar xz-utils git gh file golang-go -y
RUN --mount=type=secret,id=GH_TOKEN \
    gh auth login --with-token < /run/secrets/GH_TOKEN
# LLVM toolchain (with the Go wrapper cross-compiled for windows/386)
COPY /llvm/build-extra.sh ./pkg/llvm/
ENV GOOS=windows
ENV GOARCH=386
RUN cd pkg/llvm && bash build-extra.sh
RUN cd pkg/llvm && bash /push-build.sh --gz-tar --zstd-tar --llvm-tc --pkg-arch="i686" --pkg-os="windows" $([ "${NIGHTLY:-0}" = "1" ] && echo --nightly)
# LLVMgold plugin
RUN cd pkg/gold && bash /push-build.sh --gz-tar --zstd-tar --llvm-gold --pkg-arch="i686" --pkg-os="windows" $([ "${NIGHTLY:-0}" = "1" ] && echo --nightly)
# BFD linker
RUN cd pkg/bfd && bash /push-build.sh --gz-tar --zstd-tar --bfd --pkg-arch="i686" --pkg-os="windows" $([ "${NIGHTLY:-0}" = "1" ] && echo --nightly)
