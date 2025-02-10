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

FROM debian:bookworm AS glibc
WORKDIR /
COPY /common/utils.sh .
COPY /common/build-deps.sh .
COPY /binutils/build-bfd.sh .
COPY /binutils/push-bfd.sh .
RUN apt-get update -y
RUN apt-get install clang llvm lld binutils cmake ninja-build zstd texinfo libstdc++-$(apt list libstdc++6 2>/dev/null | grep -Eos '[0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d . -f 1)-dev wget bash gzip tar xz-utils git gh file libarchive-tools build-essential gettext libtool autoconf automake bison libzstd-dev python3 zip -y
RUN --mount=type=secret,id=GH_TOKEN \
    gh auth login --with-token < /run/secrets/GH_TOKEN
RUN git config --global user.name "Dakkshesh" && git config --global user.email "dakkshesh5@gmail.com"
RUN chmod +x build-deps.sh && bash build-deps.sh
RUN chmod +x build-bfd.sh && bash build-bfd.sh --target=avr --pack-install
RUN chmod +x push-bfd.sh && bash push-bfd.sh "glibc"

FROM alpine:edge AS musl
WORKDIR /
COPY /common/utils.sh .
COPY /common/build-deps.sh .
COPY /binutils/build-bfd.sh .
COPY /binutils/push-bfd.sh .
RUN apk add bash clang llvm lld musl-dev binutils cmake ninja libc-dev libstdc++-dev libstdc++ coreutils wget gzip tar xz git github-cli make file gcc-avr libarchive-tools build-base gettext libtool autoconf automake bison texinfo zlib-dev zstd-dev python3 zip
RUN --mount=type=secret,id=GH_TOKEN \
    gh auth login --with-token < /run/secrets/GH_TOKEN
RUN git config --global user.name "Dakkshesh" && git config --global user.email "dakkshesh5@gmail.com"
RUN chmod +x build-deps.sh && bash build-deps.sh
RUN chmod +x build-bfd.sh && bash build-bfd.sh --target=avr --pack-install
RUN chmod +x push-bfd.sh && bash push-bfd.sh "musl"