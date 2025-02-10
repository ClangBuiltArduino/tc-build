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

FROM alpine:edge AS deps-local
WORKDIR /
COPY /common/utils.sh .
COPY /common/push-build.sh .
COPY /binutils/build-bfd.sh .
COPY /sysroot/build-avr-sysroot.sh .
RUN apk add bash coreutils gzip tar xz patchelf git go github-cli make file gcc-avr libarchive-tools build-base gettext libtool autoconf automake bison texinfo zlib-dev zstd-dev python3 zip
RUN --mount=type=secret,id=GH_TOKEN \
    gh auth login --with-token < /run/secrets/GH_TOKEN
RUN chmod +x build-avr-sysroot.sh && bash build-avr-sysroot.sh
RUN mv ./install/avr-sysroot ./install/install
RUN chmod +x build-bfd.sh && bash build-bfd.sh --target=avr --linker-scripts --pack-install
RUN bash push-build.sh --gz-tar --zstd-tar --zip --sysroot=avr