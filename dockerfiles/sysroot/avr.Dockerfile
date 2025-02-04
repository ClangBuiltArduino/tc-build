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
COPY /utils.sh .
COPY /build-bfd.sh .
COPY /build-avr-sysroot.sh .
COPY /sysroot-push.sh .
RUN apk add bash coreutils gzip tar xz patchelf git go github-cli make file gcc-avr libarchive-tools build-base gettext libtool autoconf automake bison texinfo zlib-dev zstd-dev python3
RUN --mount=type=secret,id=GH_TOKEN \
    gh auth login --with-token < /run/secrets/GH_TOKEN
RUN git config --global user.name "Dakkshesh" && git config --global user.email "dakkshesh5@gmail.com"
RUN chmod +x build-avr-sysroot.sh && bash build-avr-sysroot.sh
RUN mv ./install/avr-sysroot ./install/install
RUN chmod +x build-bfd.sh && bash build-bfd.sh --target=avr --linker-scripts --pack-install
RUN chmod +x sysroot-push.sh && bash sysroot-push.sh "avr"