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

ARG DEPS_IMAGE_GLIBC=deps-glibc-local
ARG STAGE1_IMAGE_GLIBC=stage1-glibc-local

ARG DEPS_IMAGE_MUSL=deps-musl-local
ARG STAGE1_IMAGE_MUSL=stage1-musl-local

ARG FINAL_IMAGE_GLIBC=llvmgold-glibc-local
ARG FINAL_IMAGE_MUSL=llvmgold-musl-local

##############
# Deps build #
##############

FROM debian:bookworm AS deps-glibc-local
WORKDIR /
COPY /common/utils.sh .
COPY /common/build-deps.sh .
RUN apt-get update -y
RUN apt-get install clang llvm lld binutils cmake ninja-build zstd texinfo libstdc++-$(apt list libstdc++6 2>/dev/null | grep -Eos '[0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d . -f 1)-dev wget bash gzip tar xz-utils file libarchive-tools build-essential gettext libtool autoconf automake bison libzstd-dev python3 -y
RUN chmod +x build-deps.sh && bash build-deps.sh

# MUSL build
FROM alpine:edge AS deps-musl-local
WORKDIR /
COPY /common/utils.sh .
COPY /common/build-deps.sh .
RUN apk add clang llvm lld build-base musl-dev coreutils binutils make cmake ninja libc-dev gcc g++ file libstdc++-dev libstdc++ libarchive-tools xz gzip zstd zlib bash
RUN chmod +x build-deps.sh && bash build-deps.sh && ls && ls install
RUN rm -rf /source && rm -rf /build

#################
# Stage 1 build #
#################

# If DEPS_IMAGE_{VARIANT} arg is passed like we do during CI build,
# stage1 uses it as the base image to copy things from.
# If noting is passed, it depends on the deps-{VARIANT}-local stage.
FROM ${DEPS_IMAGE_GLIBC} AS deps-glibc
FROM debian:bookworm AS stage1-glibc-local
WORKDIR /
COPY --from=deps-glibc /install ./install
RUN ls && ls install
COPY /common/utils.sh .
COPY /llvm/build-llvm-stage1.sh .
RUN apt-get update -y
RUN apt-get install clang llvm lld binutils ccache cmake ninja-build zstd texinfo libstdc++-$(apt list libstdc++6 2>/dev/null | grep -Eos '[0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d . -f 1)-dev wget bash gzip tar xz-utils file libarchive-tools build-essential gettext libtool autoconf automake bison libzstd-dev python3 linux-headers-generic -y
RUN chmod +x build-llvm-stage1.sh && bash build-llvm-stage1.sh && ls && ls install
RUN rm -rf /source && rm -rf /build

# MUSL build
FROM ${DEPS_IMAGE_MUSL} AS deps-musl
FROM alpine:edge AS stage1-musl-local
WORKDIR /
COPY --from=deps-musl /install ./install
RUN ls && ls install
COPY /common/utils.sh .
COPY /llvm/build-llvm-stage1.sh .
RUN apk add clang llvm lld build-base musl-dev coreutils binutils make cmake ninja libc-dev gcc g++ file libstdc++-dev libstdc++ xz gzip libarchive-tools ccache bash python3 perl python3-dev linux-headers
RUN chmod +x build-llvm-stage1.sh && bash build-llvm-stage1.sh && ls && ls install
RUN rm -rf /source && rm -rf /build

#####################
# LLVMgold.so build #
#####################

# If STAGE1_IMAGE_{VARIANT} arg is passed like we do during CI build,
# stage2 uses it as the base image to copy things from.
# If noting is passed, it depends on the stage1-{VARIANT}-local stage.
FROM ${STAGE1_IMAGE_GLIBC} AS stage1-glibc
FROM debian:bookworm AS llvmgold-glibc-local
WORKDIR /
COPY --from=stage1-glibc /install ./install
RUN ls && ls install
COPY /common/utils.sh .
COPY /llvm/build-llvm-gold.sh .
RUN apt-get install clang llvm lld binutils ccache cmake ninja-build zstd texinfo libstdc++-$(apt list libstdc++6 2>/dev/null | grep -Eos '[0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d . -f 1)-dev wget bash gzip tar xz-utils file libarchive-tools build-essential gettext libtool autoconf automake bison libzstd-dev python3 linux-headers-generic -y
RUN chmod +x build-llvm-gold.sh && bash build-llvm-gold.sh && ls && ls install

# MUSL build
FROM ${STAGE1_IMAGE_MUSL} AS stage1-musl
FROM alpine:edge AS llvmgold-musl-local
WORKDIR /
COPY --from=stage1-musl /install ./install
RUN ls && ls install
COPY /common/utils.sh .
COPY /llvm/build-llvm-gold.sh .
RUN apk add clang llvm lld build-base musl-dev coreutils binutils make cmake ninja libc-dev gcc g++ file libstdc++-dev libstdc++ libarchive-tools xz gzip ccache bash python3 perl python3-dev linux-headers
RUN chmod +x build-llvm-gold.sh && bash build-llvm-gold.sh

########################
# Packaing LLVMgold.so #
########################

# If FINAL_IMAGE_{VARIANT} arg is passed like we do during CI build,
# This stage uses it as the base image to copy things from.
# If noting is passed, it depends on the llvmgold-{VARIANT}-local stage.
FROM ${FINAL_IMAGE_GLIBC} AS final-glibc
FROM ${FINAL_IMAGE_MUSL} AS final-musl
FROM alpine:edge AS packing
WORKDIR /
COPY --from=final-glibc /install/install ./install/install/glibc
COPY --from=final-muls /install/install ./install/install/musl
RUN ls && ls install
COPY /common/utils.sh .
COPY /llvm/push-llvm-gold.sh .
RUN apk add bash zstd coreutils gzip tar xz patchelf git github-cli file
RUN --mount=type=secret,id=GH_TOKEN \
    gh auth login --with-token < /run/secrets/GH_TOKEN
RUN git config --global user.name "Dakkshesh" && git config --global user.email "dakkshesh5@gmail.com"
RUN chmod +x push-llvm-gold.sh && bash push-llvm-gold.sh "amd64" "linux"
