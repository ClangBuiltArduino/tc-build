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

ARG DEPS_IMAGE=deps-local
ARG STAGE1_IMAGE=stage1-local
ARG STAGE2_IMAGE=stage2-local

##############
# Deps build #
##############
FROM alpine:edge AS deps-local
WORKDIR /
COPY /common/utils.sh .
COPY /common/build-deps.sh .
RUN apk add clang llvm lld build-base musl-dev coreutils binutils make cmake ninja libc-dev gcc g++ file libstdc++-dev libstdc++ libarchive-tools xz gzip zstd zlib bash
RUN bash build-deps.sh && ls && ls install
RUN rm -rf /source && rm -rf /build

#################
# Stage 1 build #
#################

# If DEPS_IMAGE arg is passed like we do during CI build,
# stage1 uses it as the base image to copy things from.
# If noting is passed, it depends on the deps-local stage.
FROM ${DEPS_IMAGE} AS deps
FROM alpine:edge AS stage1-local
WORKDIR /
COPY --from=deps /install ./install
RUN ls && ls install
COPY /common/utils.sh .
COPY /llvm/build-llvm-stage1.sh .
RUN apk add clang llvm lld build-base musl-dev coreutils binutils make cmake ninja libc-dev gcc g++ file libstdc++-dev libstdc++ xz gzip libarchive-tools ccache bash python3 perl python3-dev linux-headers
RUN bash build-llvm-stage1.sh && ls && ls install
RUN rm -rf /source && rm -rf /build

#################
# Stage 2 build #
#################

# If Stage1_IMAGE arg is passed like we do during CI build,
# stage2 uses it as the base image to copy things from.
# If noting is passed, it depends on the stage1-local stage.
FROM ${STAGE1_IMAGE} AS stage1
FROM alpine:edge AS stage2-local
WORKDIR /
COPY --from=stage1 /install ./install
RUN ls && ls install
COPY /common/utils.sh .
COPY /llvm/build-llvm-stage2.sh .
RUN apk add clang llvm lld build-base musl-dev coreutils binutils make cmake ninja libc-dev gcc g++ file libstdc++-dev libstdc++ libarchive-tools xz gzip ccache bash python3 perl python3-dev linux-headers
RUN bash build-llvm-stage2.sh
RUN rm -rf /source && rm -rf /build

###############
# Build extra #
###############

# If Stage2_IMAGE arg is passed like we do during CI build,
# postbuild uses it as the base image to copy things from.
# If noting is passed, it depends on the stage2-local stage.
FROM ${STAGE2_IMAGE} AS stage2
FROM alpine:edge AS extrabuild
WORKDIR /
COPY --from=stage2 /install/install ./install/install
COPY --from=stage2 /install/stage1 ./install/stage1
RUN ls && ls install
COPY /common/utils.sh .
COPY /common/push-build.sh .
COPY /llvm/build-extra.sh .
RUN apk add bash zstd coreutils gzip tar xz patchelf git go github-cli make file
RUN --mount=type=secret,id=GH_TOKEN \
    gh auth login --with-token < /run/secrets/GH_TOKEN
RUN bash build-extra.sh
RUN bash push-build.sh --gz-tar --zstd-tar --llvm-tc --pkg-arch="amd64" --pkg-os="linux"
